import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('lab',Path(__file__).resolve().parents[1]/'scripts/lab.py')
lab=importlib.util.module_from_spec(spec);spec.loader.exec_module(lab)

class Lifecycle(unittest.TestCase):
    def test_reserved_instances_and_invalid_prefix(self):
        for name in ['tools','browsers','tmp','local-backup']:
            with self.assertRaises(ValueError):lab.config({'INSTANCE':name})
        with self.assertRaises(ValueError):lab.config({'PREFIX':'another-project-'})
    def test_scope_rejects_unrelated_state(self):
        with tempfile.TemporaryDirectory() as folder:
            c={'runtime':folder,'name':'hug-test-fixture'}
            Path(folder,'terraform.tfstate').write_text(json.dumps({'resources':[{'mode':'managed','type':'docker_container','instances':[{'attributes':{'name':'unrelated-db','labels':[]}}]}]}))
            with self.assertRaises(ValueError):lab.ensure_scope(c)
    def test_failed_teardown_preserves_runtime(self):
        with tempfile.TemporaryDirectory() as folder:
            sentinel=Path(folder,'keep');sentinel.write_text('state')
            with patch.dict(os.environ,{'CONFIRM':'fixture'}),patch.object(lab,'destroy',side_effect=RuntimeError('fixture failure')):
                with self.assertRaises(RuntimeError):lab.execute('reset',{'runtime':folder,'instance':'fixture'})
            self.assertTrue(sentinel.exists())
    def test_operation_lock_rejects_overlap(self):
        with tempfile.TemporaryDirectory() as folder,patch.object(lab,'ROOT',Path(folder)):
            with lab.operation_lock():
                with self.assertRaises(ValueError):
                    with lab.operation_lock():pass
    def test_missing_confirmation_refuses_destroy(self):
        with patch.dict(os.environ,{},clear=True):
            with self.assertRaises(ValueError):lab.confirm({'instance':'fixture'})
