import importlib.util
import json
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('lab',ROOT/'scripts/lab.py')
lab=importlib.util.module_from_spec(spec);spec.loader.exec_module(lab)

class Contract(unittest.TestCase):
    def test_configuration(self):
        with self.assertRaises(ValueError):lab.config({'INSTANCE':'../../escape'})
        with self.assertRaises(ValueError):lab.config({'POSTGRES_PORT':'15173'})
        with self.assertRaises(ValueError):lab.config({'PROFILE':'automatic-solution'})
        a=lab.config({'INSTANCE':'albert'});b=lab.config({'INSTANCE':'brenda'})
        self.assertNotEqual(a['runtime'],b['runtime'])
        self.assertNotEqual(a['name'],b['name'])
    def test_dataset(self):
        rows=[json.loads(line) for line in (ROOT/'workshop/dataset.jsonl').read_text().splitlines()]
        self.assertEqual(len(rows),500)
        self.assertEqual([r['id'] for r in rows],list(range(rows[0]['id'],rows[0]['id']+500)))
        self.assertTrue(all(type(r['idx']) is int and isinstance(r['title'],str) for r in rows))
        self.assertEqual(''.join(r['title'][0] for r in rows[:32]),'WEARETHEGUARDIANSOFOUROWNSYSTEMS')
    def test_users(self):
        users=json.loads((ROOT/'workshop/users.yml').read_text())['users']
        self.assertEqual([u['name'] for u in users],['albert','brenda','charlie'])
        self.assertEqual(users[2]['capabilities'],[])
