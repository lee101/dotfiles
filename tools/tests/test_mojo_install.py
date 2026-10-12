#!/usr/bin/env python3
"""Unit tests for tools/mojo/install.sh — the only thing that puts the toolkit on PATH.

install.sh is a handful of lines, but it is the difference between "the mojo tools
exist" and "you can run them", so its properties are worth pinning down:

  * running it twice must be safe (idempotent, exit 0, links still resolve);
  * the symlinks it writes must follow the repo if it moves, and a stale link from
    an older checkout must be replaced rather than left dangling;
  * the dependency warnings must actually fire, which is checked by running it
    against a PATH that provably lacks those binaries rather than by trusting
    that this particular host lacks them.

Everything runs against a *copy* of tools/mojo in a temp dir, with BIN and SKILLS
redirected to temp paths, so a test run never touches ~/.local/bin or the real
skills directory.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import mojo_toolkit  # noqa: E402


BASH = shutil.which("bash") or "/bin/bash"
# The eight executables install.sh links, and the skills it publishes.
TOOL_NAMES = ("mojoflame", "mojomem", "mojoasm", "mojolint", "mojobench", "mojogpu",
              "mojoffi", "mojoparity")


def _run_install(script: Path, bin_dir: Path, skills_dir: Path, env: dict | None = None,
                 cwd: Path | None = None, timeout: int = 120):
    full = dict(os.environ) if env is None else env
    return subprocess.run(
        [BASH, str(script), str(bin_dir), str(skills_dir)],
        capture_output=True, text=True, env=full, cwd=None if cwd is None else str(cwd),
        timeout=timeout)


class InstallTestCase(unittest.TestCase):
    """A private copy of tools/mojo, so the tests never mutate the real checkout."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name)
        self.mojo = self.tmp / "mojo"
        shutil.copytree(mojo_toolkit.MOJO_DIR, self.mojo,
                        ignore=shutil.ignore_patterns("__pycache__"))
        self.script = self.mojo / "install.sh"
        self.bin = self.tmp / "bin"
        self.skills = self.tmp / "skills"

    def install(self, **kw):
        return _run_install(self.script, self.bin, self.skills, **kw)


class IdempotenceTest(InstallTestCase):
    def test_first_run_links_every_tool_and_skill(self) -> None:
        r = self.install()
        self.assertEqual(r.returncode, 0, r.stderr)
        for name in TOOL_NAMES:
            link = self.bin / name
            self.assertTrue(link.is_symlink(), f"{name} was not linked")
            self.assertTrue(link.exists(), f"{name} link dangles: {os.readlink(link)}")

        for skill in (self.mojo / "skills").iterdir():
            self.assertTrue((self.skills / skill.name).is_symlink(),
                            f"skill {skill.name} was not published")

    def test_running_twice_is_safe(self) -> None:
        first = self.install()
        self.assertEqual(first.returncode, 0, first.stderr)
        targets = {n: os.readlink(self.bin / n) for n in TOOL_NAMES}

        second = self.install()
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertNotIn("Traceback", second.stderr)
        self.assertEqual(second.stderr.strip(), "", "a re-run should not warn")
        for name in TOOL_NAMES:
            self.assertTrue((self.bin / name).exists())
            self.assertEqual(os.readlink(self.bin / name), targets[name],
                             f"{name} link moved on the second run")

    def test_third_run_after_a_stale_link_still_converges(self) -> None:
        """The classic broken state: a link left over from a deleted checkout."""
        self.install()
        for name in TOOL_NAMES:
            os.remove(self.bin / name)
        os.symlink("/nonexistent/old-checkout/bin/" + next(iter(TOOL_NAMES)),
                   self.bin / next(iter(TOOL_NAMES)))

        r = self.install()
        self.assertEqual(r.returncode, 0, r.stderr)
        for name in TOOL_NAMES:
            link = self.bin / name
            self.assertTrue(link.exists(), f"{name} still dangles after re-install")
            self.assertTrue(os.readlink(link).startswith(str(self.mojo)),
                            f"{name} points outside the checkout")

    def test_link_target_follows_a_moved_repo(self) -> None:
        """`ln -sfn` with a resolved absolute source is what makes this work."""
        self.install()
        moved = self.tmp / "moved"
        self.mojo.rename(moved)
        script = moved / "install.sh"
        r = _run_install(script, self.bin, self.skills)
        self.assertEqual(r.returncode, 0, r.stderr)
        for name in TOOL_NAMES:
            link = self.bin / name
            self.assertTrue(link.exists(), f"{name} dangles after the repo moved")
            self.assertTrue(os.readlink(link).startswith(str(moved)))


class MakesExecutableTest(InstallTestCase):
    def test_install_makes_the_tools_executable(self) -> None:
        for name in TOOL_NAMES:
            p = self.mojo / "bin" / name
            p.chmod(0o644)
        r = self.install()
        self.assertEqual(r.returncode, 0, r.stderr)
        for name in TOOL_NAMES:
            self.assertTrue(os.access(self.mojo / "bin" / name, os.X_OK),
                            f"{name} is still not executable")

    def test_a_missing_tool_fails_loudly(self) -> None:
        """`set -e` should abort on a tool that is not in the checkout, and the
        failure must not look like success."""
        (self.mojo / "bin" / "mojoparity").unlink()
        r = self.install()
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("mojoparity", r.stderr)


class DependencyWarningTest(InstallTestCase):
    """The dependency lines are the installer's only feedback; prove they fire."""

    # coreutils + bash + python3, and deliberately no gcc/gdb/addr2line/objdump/nm
    _NEEDED = ("bash", "dirname", "basename", "mkdir", "chmod", "ln", "ls", "cat",
               "python3")

    def _minimal_env(self) -> dict:
        box = self.tmp / "minbin"
        box.mkdir(exist_ok=True)
        for name in self._NEEDED:
            src = shutil.which(name)
            if src:
                (box / name).symlink_to(src)
        return {"PATH": str(box), "HOME": str(self.tmp / "home")}

    def test_warnings_fire_when_the_tools_are_absent(self) -> None:
        r = self.install(env=self._minimal_env())
        self.assertEqual(r.returncode, 0, r.stderr)
        for dep in ("gcc", "gdb", "addr2line", "objdump", "nm", "valgrind"):
            self.assertIn(f"missing: {dep}" if dep != "valgrind" else "optional: valgrind",
                          r.stdout, f"no warning for {dep}:\n{r.stdout}")
        self.assertIn("missing: numpy", r.stdout)

    def test_each_warning_names_the_binary_it_is_about(self) -> None:
        """A warning that names the wrong binary sends the user to install the
        wrong package."""
        r = self.install(env=self._minimal_env())
        expected = {
            "gcc": "mojomem allocation shim",
            "gdb": "mojoflame sampling",
            "addr2line": "mojomem symbolization",
            "objdump": "mojoasm --bin",
            "nm": "mojoffi --check",
            "numpy": "mojoparity",
        }
        for dep, consumer in expected.items():
            line = next((l for l in r.stdout.splitlines() if dep in l), "")
            self.assertTrue(line, f"no line mentioning {dep}")
            self.assertIn(consumer, line,
                          f"the {dep} warning does not mention {consumer}: {line}")

    def test_no_warnings_when_everything_is_present(self) -> None:
        missing = [d for d in ("gcc", "gdb", "addr2line", "objdump", "nm", "valgrind")
                   if shutil.which(d) is None]
        if missing:
            self.skipTest(f"absent on this host, so warnings would still fire: {missing}")
        try:
            import numpy  # noqa: F401
        except Exception:
            self.skipTest("numpy not importable here")
        r = self.install()
        self.assertEqual(r.stdout.count("missing:"), 0, r.stdout)
        self.assertEqual(r.stdout.count("optional:"), 0, r.stdout)


class PathNoteTest(InstallTestCase):
    def test_not_on_path_is_noted(self) -> None:
        r = self.install(env={"PATH": "/usr/bin:/bin", "HOME": str(self.tmp / "h")})
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("is not on PATH", r.stdout)

    def test_on_path_is_not_warned_about(self) -> None:
        env = dict(os.environ)
        env["PATH"] = f"{self.bin}:{env.get('PATH', '')}"
        r = _run_install(self.script, self.bin, self.skills, env=env)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertNotIn("is not on PATH", r.stdout)

    def test_custom_destination_directories_are_honoured(self) -> None:
        other = self.tmp / "elsewhere" / "bin"
        otherskills = self.tmp / "elsewhere" / "skills"
        r = _run_install(self.script, other, otherskills)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((other / "mojomem").is_symlink())
        self.assertTrue((otherskills / "mojo-perf").is_symlink())
        self.assertFalse(self.bin.exists(), "the default BIN must not be created")


class InstalledToolRunsTest(InstallTestCase):
    """The point of the installer: after it runs, a tool works by name."""

    def test_tool_is_reachable_and_runnable_through_its_link(self) -> None:
        self.install()
        r = subprocess.run([str(self.bin / "mojomem"), "--help"],
                           capture_output=True, text=True, timeout=120)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("mojomem", r.stdout)


if __name__ == "__main__":
    unittest.main()