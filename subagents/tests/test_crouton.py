import os, pathlib, subprocess, tempfile, unittest
D = pathlib.Path(__file__).resolve().parents[1]

class Crouton(unittest.TestCase):
    def test_syntax(self):
        for n in ("op-crouton.sh", "di-crouton.sh", "mjj-crouton.sh", "pi-crouton.sh"):
            self.assertEqual(subprocess.run(["bash", "-n", str(D / n)]).returncode, 0)

    def test_key_required(self):
        env = {k: v for k, v in os.environ.items() if k != "OPENROUTER_API_KEY"}
        for n in ("di-crouton.sh", "mjj-crouton.sh", "pi-crouton.sh"):
            r = subprocess.run(["bash", str(D / n)], env=env, capture_output=True, text=True)
            self.assertEqual(r.returncode, 2, n)

    def test_di_env(self):
        with tempfile.TemporaryDirectory() as t:
            fake = pathlib.Path(t) / "di"
            fake.write_text('#!/usr/bin/env bash\necho "$FX_MODEL $FX_PROVIDER ${OPENPATHS_API_KEY-unset}"\n')
            fake.chmod(0o755)
            env = dict(os.environ, DI=str(fake), OPENROUTER_API_KEY="k", OPENPATHS_API_KEY="x")
            r = subprocess.run(["bash", str(D / "di-crouton.sh")], env=env, capture_output=True, text=True)
            self.assertEqual(r.stdout.strip(), "stealth/crouton-alpha openpaths unset", r.stderr)

if __name__ == "__main__":
    unittest.main()
