import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from _platform import launcher_command, write_runner, write_script

WRAPPER = Path(__file__).resolve().parents[1] / "di-bunny-file.sh"


class FileLauncherTests(unittest.TestCase):
    def test_saved_prompt_exit_and_bounded_preview(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            runner = path / "runner.py"
            write_runner(runner)
            binary = path / "fx"
            write_script(binary, "#!/usr/bin/env python3\nimport sys\nassert sys.stdin.read() == 'literal $(false)\\n'\nassert sys.argv[1:] == ['ask','--full-access','--json','--no-save'], sys.argv[1:]\nprint('secret early line')\nfor i in range(300): print('line'+str(i))\nsys.exit(7)\n")
            prompt = path / "input.txt"
            prompt.write_text("literal $(false)\n")
            env = {**os.environ, "DI": str(binary), "DI_AGENT_RUNNER": str(runner),
                   "OPENROUTER_API_KEY": "fixture", "DI_RUN_DIR": str(path / "runs")}
            result = subprocess.run(launcher_command(WRAPPER, "pilot", str(prompt)), env=env, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 7, result.stderr)
            self.assertNotIn("secret early line", result.stdout)
            self.assertIn("line299", result.stdout)
            self.assertEqual((path / "runs/pilot.prompt.txt").read_text(), prompt.read_text())
            self.assertIn("secret early line", (path / "runs/pilot.log").read_text())
            again = subprocess.run(launcher_command(WRAPPER, "pilot", str(prompt)), env=env, capture_output=True, text=True)
            self.assertNotEqual(again.returncode, 0)
            bad = subprocess.run(launcher_command(WRAPPER, "../escape", str(prompt)), env=env, capture_output=True)
            self.assertEqual(bad.returncode, 2)


    def test_access_flag_is_overridable(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            runner = path / "runner.py"
            write_runner(runner)
            binary = path / "fx"
            write_script(binary, 
                "#!/usr/bin/env python3\nimport sys\n"
                "sys.stdin.read()\n"
                "assert sys.argv[1:] == ['ask','--auto','--json','--no-save'], sys.argv[1:]\n"
                "print('ok')\n"
            )
            prompt = path / "input.txt"
            prompt.write_text("go\n")
            env = {**os.environ, "DI": str(binary), "DI_AGENT_RUNNER": str(runner),
                   "OPENROUTER_API_KEY": "fixture", "DI_RUN_DIR": str(path / "runs"),
                   "DI_BUNNY_ACCESS": "--auto"}
            result = subprocess.run(launcher_command(WRAPPER, "pilot2", str(prompt)), env=env, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)

    def _run_with_binary(self, path, body, **overrides):
        runner = path / "runner.py"
        write_runner(runner)
        binary = path / "fx"
        write_script(binary, body)
        prompt = path / "input.txt"
        prompt.write_text("go\n")
        env = {**os.environ, "DI": str(binary), "DI_AGENT_RUNNER": str(runner),
               "OPENROUTER_API_KEY": "fixture", "DI_RUN_DIR": str(path / "runs"),
               "DI_BUNNY_ATTEMPTS": "3", **overrides}
        return subprocess.run(launcher_command(WRAPPER, "pilot3", str(prompt)), env=env,
                              capture_output=True, text=True, timeout=20)

    def test_provider_stream_failure_is_retried(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            marker = path / "attempts"
            body = (
                "#!/usr/bin/env python3\nimport sys,os\n"
                "sys.stdin.read()\n"
                f"n = len(open({str(marker)!r}).read()) if os.path.exists({str(marker)!r}) else 0\n"
                f"open({str(marker)!r},'w').write('x'*(n+1))\n"
                "if n == 0:\n"
                "    print('{\"error\":\"OpenPathsStreamFailed\"}')\n"
                "    sys.exit(1)\n"
                "print('{\"exit_code\":0,\"final_output\":\"done\"}')\n"
            )
            result = self._run_with_binary(path, body)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("attempt=2/3", result.stdout)
            self.assertTrue((path / "runs/pilot3.log.attempt1").exists())

    def test_non_transient_failure_is_not_retried(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            body = ("#!/usr/bin/env python3\nimport sys\nsys.stdin.read()\n"
                    "print('{\"error\":\"InvalidAskArgs\"}')\nsys.exit(1)\n")
            result = self._run_with_binary(path, body)
            self.assertEqual(result.returncode, 1)
            self.assertIn("attempt=1/3", result.stdout)
            self.assertFalse((path / "runs/pilot3.log.attempt1").exists())

    def test_attempts_bound_is_validated(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            result = self._run_with_binary(path, "#!/usr/bin/env python3\n", DI_BUNNY_ATTEMPTS="0")
            self.assertEqual(result.returncode, 2)
            self.assertIn("between 1 and 99", result.stderr)


if __name__ == "__main__":
    unittest.main()
