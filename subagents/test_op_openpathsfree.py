import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('op-openpathsfree.sh')

class WrapperTests(unittest.TestCase):
    def test_route_and_private_config(self):
        with tempfile.TemporaryDirectory() as tmp:
            fake = Path(tmp) / 'op'
            fake.write_text('#!/usr/bin/env python3\nimport os,json,pathlib,sys\np=pathlib.Path(os.environ["PI_CODING_AGENT_DIR"])\nprint(json.dumps({"argv":sys.argv[1:],"models":json.loads((p/"models.yml").read_text()),"config":json.loads((p/"free.yml").read_text()),"dir":str(p),"key_present":bool(os.environ.get("OPENPATHS_API_KEY"))}))\n')
            fake.chmod(0o755)
            env = dict(os.environ, OP=str(fake), OPENPATHS_API_KEY='TEST_SECRET_DO_NOT_OUTPUT')
            run = subprocess.run([str(SCRIPT),'--print','--no-tools','prompt'],env=env,text=True,capture_output=True,check=True)
            self.assertNotIn('TEST_SECRET_DO_NOT_OUTPUT',run.stdout)
            result = json.loads(run.stdout)
            self.assertTrue(result['key_present'])
            self.assertFalse(Path(result['dir']).exists())
            self.assertIn('openpaths-free/nous/poolside/laguna-s-2.1:free',result['argv'])
            self.assertEqual(result['config']['retry']['fallbackChains'],{})
            self.assertEqual(result['models']['providers']['openpaths-free']['apiKey'],'OPENPATHS_API_KEY')

    def test_rejects_paid_or_routing_override(self):
        env = dict(os.environ,OPENPATHS_API_KEY='test')
        for args in [['--model','paid/model'],['--config=x'],['--provider=x']]:
            self.assertEqual(subprocess.run([str(SCRIPT),*args],env=env,capture_output=True).returncode,2)
        env['OP_FREE_MODEL']='paid/model'
        self.assertEqual(subprocess.run([str(SCRIPT),'prompt'],env=env,capture_output=True).returncode,2)
        env.pop('OP_FREE_MODEL')
        env.pop('OPENPATHS_API_KEY')
        self.assertEqual(subprocess.run([str(SCRIPT),'prompt'],env=env,capture_output=True).returncode,2)

if __name__ == '__main__':
    unittest.main()
