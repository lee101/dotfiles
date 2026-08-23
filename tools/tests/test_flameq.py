import subprocess
import tempfile
import unittest
from pathlib import Path


TOOL = Path(__file__).parents[1] / "flameq"


class FlameQTest(unittest.TestCase):
    def test_query_and_render_folded_profile(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            profile = directory / "sample.folded"
            profile.write_text("main;decode;resize 7\nmain;decode;parse 3\nmain;cache 2\n")
            query = subprocess.run([str(TOOL), "query", str(profile), "--match", "decode"], text=True, capture_output=True, check=True)
            self.assertIn("samples: 12", query.stdout)
            self.assertIn("main;decode", query.stdout)
            image = directory / "profile.svg"
            subprocess.run([str(TOOL), "render", str(profile), "--out", str(image)], check=True)
            self.assertIn("<svg", image.read_text())


if __name__ == "__main__":
    unittest.main()
