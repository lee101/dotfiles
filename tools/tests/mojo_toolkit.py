#!/usr/bin/env python3
"""Shared subprocess driver for the tools in ``tools/mojo/bin``.

The mojo tools are executables, not importable modules (they have no package and
they are invoked by name from the skills), so every test drives them the way a user
does: as a subprocess with an explicit argv.

This module is the single place that knows how to do that hermetically — a private
temp cwd, a scrubbed environment, and a hard timeout so a hung tool fails one test
instead of hanging the whole suite.

It is imported by the ``test_mojo_*.py`` files and is not itself a test module
(it does not match the ``test_*.py`` discovery pattern).

Kept free of pytest-only features: ``tools/test-all.sh`` falls back to
``python3 -m unittest discover`` when pytest is missing.
"""
from __future__ import annotations

import os
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
MOJO_DIR = TOOLS_DIR / "mojo"
BIN_DIR = MOJO_DIR / "bin"
SHIM_C = BIN_DIR / "mojomem_shim.c"
INSTALL_SH = MOJO_DIR / "install.sh"
REPO_DIR = TOOLS_DIR.parent

# every tool, with the argv token its own usage text must contain
TOOLS = {
    "mojolint": "mojolint",
    "mojobench": "mojobench",
    "mojomem": "mojomem",
    "mojoasm": "mojoasm",
    "mojoflame": "mojoflame",
    "mojogpu": "mojogpu",
    "mojoffi": "mojoffi",
    "mojoparity": "mojoparity",
}

# Environment variables that would make a test non-hermetic or hijack a tool's
# toolchain discovery. MODULAR_HOME/MOJO are dropped deliberately: a tool that
# needs the compiler must be told about it explicitly by the test that wants it.
_SCRUB = (
    "MOJO",
    "MODULAR_HOME",
    "MODULAR_CACHE_DIR",
    "PYTHONPATH",
    "PYTHONHOME",
    "PYTHONSTARTUP",
    "LD_PRELOAD",
    "LD_LIBRARY_PATH",
    "PYTHONDONTWRITEBYTECODE",
)


def tool_path(name: str) -> str:
    """Absolute path to a tool, by name."""
    p = BIN_DIR / name
    if not p.is_file():
        raise FileNotFoundError(f"{p} is missing from the toolkit")
    return str(p)


def have(binary: str) -> bool:
    return shutil.which(binary) is not None


def tool_exists(name: str) -> bool:
    return (BIN_DIR / name).is_file()


def have_module(mod: str) -> bool:
    try:
        __import__(mod)
    except Exception:  # noqa: BLE001 - a broken numpy is as good as absent
        return False
    return True


def _cpu_affinity() -> str | None:
    """This process's allowed CPU set as a GOMP_CPU_AFFINITY value, or None.

    Linux ``sched_getaffinity(2)`` already knows the answer; Python only exposes it
    through ``os.sched_getaffinity`` (Linux-only, 3.3+). The empty set is legal and
    means "no allowed CPU", which is not worth pinning anything to.
    """
    get = getattr(os, "sched_getaffinity", None)
    if get is None:
        return None
    try:
        cpus = sorted(get(0))
    except OSError:
        return None
    return ",".join(str(c) for c in cpus) if cpus else None


_CPU_AFFINITY = _cpu_affinity()


def clean_env(extra: dict | None = None) -> dict:
    """os.environ minus the toolchain hooks, plus whatever the test asked for."""
    env = {k: v for k, v in os.environ.items() if k not in _SCRUB}
    env.setdefault("HOME", str(Path.home()))
    # CPU-bound children must not inherit the runner's own CPU mask. mojobench
    # times /bin/sh targets whose median is a fraction of a millisecond; a sibling
    # test's load, a thermal stop or a scheduler migration inside that window moves
    # the number enough to flip a verdict, and the failure is about this harness's
    # environment, not about the tool being tested. Pinning to the CPU set that is
    # already allowed keeps the suite's timing assertions meaningful.
    if _CPU_AFFINITY is not None:
        env["GOMP_CPU_AFFINITY"] = _CPU_AFFINITY
    if extra:
        env.update({k: str(v) for k, v in extra.items()})
    return env


_TIME_RE = re.compile(r"^(?P<n>\d+(?:\.\d+)?)(?P<unit>us|ms|s)$")
_UNIT_US = {"s": 1e9, "ms": 1e3, "us": 1.0}


def parse_duration(s: str) -> float:
    """A `123us` / `1.20ms` / `0.003s` cell in microseconds.

    Every timing test in the suite hand-rolled its own converter, and every copy of
    it assumed that a string ending in ``us`` has no decimal point. mojobench rounds
    to whole microseconds, so the unit is decided by the suffix alone and that
    happens to hold — but `float(s[:-2])` on ``979us`` yields 979.0 while
    `float(s[:-1])` on the same string's digit soup yields whatever the number is,
    and the two branches disagree the moment the format gains a decimal. One
    converter, matched on the suffix, so no test can quietly measure the wrong unit.
    """
    m = _TIME_RE.match(s.strip())
    if not m:
        raise ValueError(f"not a duration this suite understands: {s!r}")
    return float(m.group("n")) * _UNIT_US[m.group("unit")]


def duration_quantum(s: str) -> float:
    """The rounding error of a rendered duration cell, in microseconds.

    mojobench gates its verdict on the full-precision float but prints microseconds
    rounded to whole ones, so a comparison the report shows as "8.0ms vs 8.4ms" was
    decided on numbers the reader cannot see. Anything within this much of the gate
    is a question the rendered report cannot answer, and a test that insists on an
    answer there is testing rounding, not the tool.
    """
    m = _TIME_RE.match(s.strip())
    if not m:
        raise ValueError(f"not a duration this suite understands: {s!r}")
    unit, digits = m.group("unit"), len(m.group("n").split(".")[1])
    return 10.0 ** -digits * _UNIT_US[unit]


class Result(tuple):
    """(rc, stdout, stderr) with the parts still reachable by name."""

    __slots__ = ()

    def __new__(cls, rc: int, out: str, err: str) -> "Result":
        return super().__new__(cls, (rc, out, err))

    @property
    def rc(self) -> int:
        return self[0]

    @property
    def out(self) -> str:
        return self[1]

    @property
    def err(self) -> str:
        return self[2]

    @property
    def text(self) -> str:
        return self[1] + self[2]


def run(argv, cwd=None, timeout: int = 120, env: dict | None = None,
        stdin: str | None = None) -> Result:
    """Run argv to completion. Never raises on a non-zero exit; times out loudly.

    stdin is always a pipe, never inherited. A tool that spawns a child which reads
    stdin — mojobench runs its targets that way — otherwise has the test runner's
    own stdin behind it, and a /bin/sh that finds readable input there consumes it
    as script text. That looks exactly like a target that never ran.
    """
    try:
        p = subprocess.run(
            [str(a) for a in argv],
            cwd=None if cwd is None else str(cwd),
            env=clean_env(env),
            input="" if stdin is None else stdin,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        raise AssertionError(
            f"timed out after {timeout}s: {' '.join(str(a) for a in argv)}"
        ) from None
    return Result(p.returncode, p.stdout, p.stderr)


def run_tool(name: str, *args, timeout: int = 120, cwd=None, env: dict | None = None,
             stdin: str | None = None) -> Result:
    """Run a toolkit tool by name with explicit arguments."""
    return run([sys.executable, tool_path(name), *args],
               cwd=cwd, timeout=timeout, env=env, stdin=stdin)


def mojo_env() -> dict | None:
    """Env that makes the pixi-installed `mojo` usable, or None if there is none.

    Mojo is not on PATH in this checkout; it lives in profiling/mojo/.pixi. The
    tests that need a real compiler ask for this and skip when it is None.
    """
    pixi = REPO_DIR / "profiling" / "mojo" / ".pixi" / "envs" / "default"
    mojo = pixi / "bin" / "mojo"
    if not mojo.is_file():
        return None
    return {
        "MOJO": str(mojo),
        "MODULAR_HOME": str(pixi / "share" / "max"),
        "PATH": f"{pixi / 'bin'}:{os.environ.get('PATH', '')}",
    }


requires_mojo = unittest.skipIf(
    mojo_env() is None, "no `mojo` compiler available (expected profiling/mojo/.pixi)"
)


def write(path: Path, text: str) -> Path:
    """Write text (dedent-free, exactly as given) and return the path."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return path


def write_mojo(dirpath: Path, name: str, body: str) -> Path:
    return write(Path(dirpath) / name, body.lstrip("\n"))


# Shared mixin for the argv-shape contract. It lives outside any TestCase so that
# neither runner collects it on its own: pytest walks Test* classes when a module is
# passed to it directly, and unittest discovers by module name — both would try to
# run this class as a suite and fail three times over, once per module that uses it.
class ToolContractMixin:
    """`--help` works, a missing positional is a usage error, an unknown flag is not
    silently accepted.

    Every tool in this toolkit has to survive these, because the difference between
    "CI is red for a reason" and "CI is red because argparse crashed" is the whole
    point of a linter that runs unattended.
    """

    tool = ""          # set by the subclass: the executable's name
    usage_token = ""   # the tool's own name, which its usage text must mention

    def setUp(self) -> None:
        # Every test gets its own cwd so nothing depends on where the runner was
        # invoked from, and no fixture is visible to a sibling test.
        self._tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmpdir.cleanup)
        self.tmp = Path(self._tmpdir.name)

    def run_tool(self, *args, **kw) -> Result:
        kw.setdefault("cwd", self.tmp)
        return run_tool(self.tool, *args, **kw)

    # ---- argv-shape contract, shared by every tool in the toolkit -------------

    # A checkout may ship some of the eight tools and not others. These shared
    # argv-shape tests cannot say anything useful about a tool that is not here,
    # and without this they fail with FileNotFoundError in whatever submodule
    # happens to be under test. Checked per test, not by decorator: `tool` is set
    # by the subclass, which does not exist when this mixin's body runs.
    def require_tool(self) -> None:
        if not self.tool:
            self.skipTest("test case does not name a tool")
        if not tool_exists(self.tool):
            self.skipTest(f"tools/mojo/bin/{self.tool} is not in this checkout")

    def test_help_exits_zero_and_names_the_program(self) -> None:
        self.require_tool()
        r = self.run_tool("--help")
        self.assertEqual(r.rc, 0, f"--help failed: {r.text}")
        self.assertIn(self.usage_token or self.tool, r.text)

    def test_no_arguments_is_a_usage_error_not_a_traceback(self) -> None:
        self.require_tool()
        r = self.run_tool()
        self.assertNotEqual(r.rc, 0, f"no-arg invocation should fail: {r.text}")
        self.assertNotIn("Traceback", r.text)
        self.assertIn("usage", r.text.lower())

    def test_unknown_flag_is_rejected(self) -> None:
        self.require_tool()
        r = self.run_tool("--definitely-not-a-flag")
        self.assertNotEqual(r.rc, 0)
        self.assertNotIn("Traceback", r.text)


class ToolTestCase(ToolContractMixin, unittest.TestCase):
    """What every test_mojo_*.py case inherits: a private cwd and the argv contract.

    Subclasses set ``tool`` and ``usage_token``. Anything a test needs on disk goes
    under ``self.tmp``; nothing may depend on the directory the runner was invoked
    from, because the suite is run both from the repo root and from ``tools/``.

    Note the MRO: the mixin comes first, so a subclass that overrides ``setUp``
    and forgets to chain leaves the mixin's tests without a temp dir. Subclasses
    must call ``super().setUp()``.
    """