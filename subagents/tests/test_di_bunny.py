import json,os,pathlib,subprocess,tempfile,unittest
LAUNCHER=pathlib.Path(__file__).resolve().parents[1]/'di-bunny.sh'
class TestLauncher(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
  p=pathlib.Path(self.tmp.name)
  self.runner=p/'runner.py';self.runner.write_text('import os,sys\nos.execvp(sys.argv[1],sys.argv[1:])\n')
  self.binary=p/'fx';self.binary.write_text('#!/usr/bin/env python3\nimport os,sys,json\nprint(json.dumps({"args":sys.argv[1:],"model":os.environ["FX_MODEL"],"provider":os.environ["FX_PROVIDER"],"steps":os.environ["FX_MAX_AGENT_STEPS"],"openpaths": "OPENPATHS_API_KEY" in os.environ}))\n');self.binary.chmod(0o700)
  self.env={**os.environ,'DI':str(self.binary),'DI_AGENT_RUNNER':str(self.runner),'OPENROUTER_API_KEY':'fixture','OPENPATHS_API_KEY':'fixture','FX_MAX_AGENT_STEPS':'80','DI_BUNNY_TIMEOUT_SECONDS':'10'}
 def run_launcher(self,**overrides):
  return subprocess.run([str(LAUNCHER),'ask','--json','--','spaces; $(false)'],env={**self.env,**overrides},capture_output=True,text=True,timeout=5)
 def test_happy_path(self):
  r=self.run_launcher();self.assertEqual(r.returncode,0,r.stderr); d=json.loads(r.stdout);self.assertEqual(d,{'args':['ask','--json','--','spaces; $(false)'],'model':'stealth/space-bunny-alpha','provider':'openrouter','steps':'80','openpaths':False})
 def test_leading_zero(self):
  r=self.run_launcher(FX_MAX_AGENT_STEPS='0080',DI_BUNNY_TIMEOUT_SECONDS='00008');self.assertEqual(r.returncode,0,r.stderr);self.assertEqual(json.loads(r.stdout)['steps'],'80')
 def test_bad_bounds(self):
  for key,values in {'FX_MAX_AGENT_STEPS':['0','-1','1001','999999999999999999999999','abc'],'DI_BUNNY_TIMEOUT_SECONDS':['0','21601','-1','abc','999999999999999999999999']}.items():
   for val in values:
    with self.subTest(key=key,val=val):self.assertEqual(self.run_launcher(**{key:val}).returncode,2)
 def test_missing_key(self):self.assertEqual(self.run_launcher(OPENROUTER_API_KEY='').returncode,2)
 def test_missing_binary(self):self.assertEqual(self.run_launcher(DI='/no/such/fx').returncode,2)
if __name__=='__main__':unittest.main()
