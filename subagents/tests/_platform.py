"""Portability shims so the launcher tests run on Linux, macOS and Windows.

On Windows, `bash` from CreateProcess resolves to System32's WSL stub, shebang
fixtures cannot be exec'd by Python, and `python3` is the Store alias. These
helpers route everything through Git Bash and the running interpreter instead.
"""
import os
import pathlib
import shutil
import sys

WINDOWS = os.name == "nt"


def _find_git_bash():
    override = os.environ.get("DI_TEST_BASH")
    if override:
        return override
    candidates = []
    git = shutil.which("git")
    if git:
        # <Git>/cmd/git.exe or <Git>/mingw64/bin/git.exe -> <Git>/bin/bash.exe
        for parent in pathlib.Path(git).resolve().parents:
            candidates.append(parent / "bin" / "bash.exe")
    for root in (os.environ.get("ProgramFiles"), os.environ.get("ProgramFiles(x86)"),
                 os.environ.get("LOCALAPPDATA") and os.path.join(os.environ["LOCALAPPDATA"], "Programs")):
        if root:
            candidates.append(pathlib.Path(root) / "Git" / "bin" / "bash.exe")
    for candidate in candidates:
        if candidate.is_file():
            return str(candidate)
    raise RuntimeError("Git Bash not found; set DI_TEST_BASH to bash.exe")


BASH = _find_git_bash() if WINDOWS else "bash"


def _msys_path(path):
    path = str(path).replace("\\", "/")
    if len(path) > 1 and path[1] == ":":
        path = "/" + path[0].lower() + path[2:]
    return path


def write_script(path, body):
    """Write an executable fixture; on Windows point its shebang at this Python."""
    if WINDOWS and body.startswith("#!/usr/bin/env python3"):
        body = "#!" + _msys_path(sys.executable) + body[len("#!/usr/bin/env python3"):]
    path.write_text(body, newline="\n")
    path.chmod(0o700)


# Stand-in for monitoring/run_agent.py: run argv as-is. On Windows, exec through
# Git Bash so `timeout` is coreutils (not timeout.exe) and shebang fixtures run.
# The argv goes through a script file because Windows command-line quoting
# mangles an inline `bash -c '"$@"'`.
def write_runner(path):
    if not WINDOWS:
        path.write_text("import os,sys\nos.execvp(sys.argv[1], sys.argv[1:])\n", newline="\n")
        return
    exec_script = path.with_name(path.stem + "-exec.sh")
    exec_script.write_text('exec "$@"\n', newline="\n")
    path.write_text(
        "import subprocess,sys\n"
        f"sys.exit(subprocess.call([{BASH!r}, {str(exec_script)!r}, *sys.argv[1:]]))\n",
        newline="\n")


def launcher_command(script, *args):
    return [BASH, str(script), *args]
