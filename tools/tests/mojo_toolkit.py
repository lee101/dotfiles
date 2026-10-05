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
import shutil
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


def have_module(mod: str) -> bool:
    try:
        __import__(mod)
    except Exception:  # noqa: BLE001 - a broken numpy is as good as absent
        return False
    return True


def clean_env(extra: dict | None = None) -> dict:
    """os.environ minus the toolchain hooks, plus whatever the test asked for."""
    env = {k: v for k, v in os.environ.items() if k not in _SCRUB}
    env.setdefault("HOME", str(Path.home()))
    if extra:
        env.update({k: str(v) for k, v in extra.items()})
    return env


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
    """Run argv to completion. Never raises on a non-zero exit; times out loudly."""
    try:
        p = subprocess.run(
            [str(a) for a in argv],
            cwd=None if cwd is None else str(cwd),
            env=clean_env(env),
            input=stdin,
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

    def test_help_exits_zero_and_names_the_program(self) -> None:
        r = self.run_tool("--help")
        self.assertEqual(r.rc, 0, f"--help failed: {r.text}")
        self.assertIn(self.usage_token or self.tool, r.text)

    def test_no_arguments_is_a_usage_error_not_a_traceback(self) -> None:
        r = self.run_tool()
        self.assertNotEqual(r.rc, 0, f"no-arg invocation should fail: {r.text}")
        self.assertNotIn("Traceback", r.text)
        self.assertIn("usage", r.text.lower())

    def test_unknown_flag_is_rejected(self) -> None:
        r = self.run_tool("--definitely-not-a-flag")
        self.assertNotEqual(r.rc, 0)
        self.assertNotIn("Traceback", r.text)


class ToolTestCase(ToolContractMixin, unittest.TestCase):
    """What every test_mojo_*.py case inherits: a private cwd and the argv contract.

    Subclasses set ``tool`` and ``usage_token``. Anything a test needs on disk goes
    under ``self.tmp``; nothing may depend on the directory the runner was invoked
    from, because the suite is run both from the repo root and from ``tools/``.
    """