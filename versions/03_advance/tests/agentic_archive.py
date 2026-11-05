import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('sessions', Path(__file__).resolve().parents[1] / 'scripts/agentic_sessions.py')
sessions = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sessions)


class ArchiveTest(unittest.TestCase):
    def test_pi_roundtrip_and_delete(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, {'PI_CODING_AGENT_DIR': tmp}):
            root = Path(tmp)
            (root / 'settings.json').write_text(json.dumps({'sessionDir': 'custom'}))
            path = root / 'custom/project/session.jsonl'
            path.parent.mkdir(parents=True)
            content = json.dumps({'type': 'session', 'id': 'one', 'cwd': '/project'}) + '\n'
            content += json.dumps({'type': 'session_info', 'name': 'Named session'}) + '\n'
            path.write_text(content)
            def run(action, **kwargs):
                return sessions.execute({'provider': 'pi-acp', 'action': action, **kwargs})
            item = run('list', cwd='/project')['items'][0]
            self.assertEqual(item['title'], 'Named session')
            self.assertEqual(run('list', cwd='/elsewhere')['items'], [])
            with self.assertRaises(RuntimeError):
                run('archive', session_id='one', path='/wrong/path')
            self.assertTrue(path.exists())
            run('archive', session_id='one', path=str(path))
            self.assertFalse(path.exists())
            self.assertEqual(run('list')['items'], [])
            archived = run('list', archived=True)['items'][0]
            self.assertEqual(Path(archived['path']).read_text(), content)
            # Never overwrite a destination file.
            path.write_text(content)
            with self.assertRaises(FileExistsError):
                run('unarchive', session_id='one', path=archived['path'])
            path.unlink()
            run('unarchive', session_id='one', path=archived['path'])
            self.assertEqual(path.read_text(), content)
            run('archive', session_id='one', path=str(path))
            run('delete', session_id='one', path=archived['path'])
            self.assertFalse(Path(archived['path']).exists())
            self.assertEqual(run('list', archived=True)['items'], [])

    def test_codex_pagination(self):
        class Client:
            def __init__(self): self.calls = []
            def call(self, method, params):
                self.calls.append((method, params))
                return {'data': [{'id': str(len(self.calls)), 'updatedAt': 1}],
                        'nextCursor': 'page2' if len(self.calls) == 1 else None}
        client = Client()
        items = sessions.codex_items(client, True)
        self.assertEqual(len(items), 2)
        self.assertEqual(client.calls[1][1]['cursor'], 'page2')
        self.assertIn('subAgent', client.calls[0][1]['sourceKinds'])
        self.assertNotIn('cwd', client.calls[0][1])


unittest.main()
