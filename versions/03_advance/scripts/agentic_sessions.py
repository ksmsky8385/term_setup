"""Session archive operations. JSON request on stdin, JSON result on stdout."""
import json
import os
from pathlib import Path
import subprocess
import sys
import signal
from datetime import datetime, timezone


class Codex:
    def __enter__(self):
        self.proc = subprocess.Popen(['codex', 'app-server'], stdin=subprocess.PIPE,
                                     stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        self.seq = 0
        try:
            self.call('initialize', {'clientInfo': {'name': 'nvim_sessions', 'version': '1.0'}})
        except BaseException:
            self.__exit__()
            raise
        self.proc.stdin.write(json.dumps({'method': 'initialized'}) + '\n')
        self.proc.stdin.flush()
        return self

    def call(self, method, params):
        self.seq += 1
        self.proc.stdin.write(json.dumps({'id': self.seq, 'method': method, 'params': params}) + '\n')
        self.proc.stdin.flush()
        for line in self.proc.stdout:
            message = json.loads(line)
            if message.get('id') != self.seq:
                continue
            if message.get('error'):
                raise RuntimeError(message['error'].get('message', 'Codex request failed'))
            return message.get('result', {})
        raise RuntimeError('Codex connection closed')

    def __exit__(self, *_):
        self.proc.terminate()
        try:
            self.proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait()


def codex_items(client, archived, cwd=None):
    items, cursor, seen = [], None, set()
    while True:
        params = {'archived': archived, 'limit': 100, 'modelProviders': [], 'sortKey': 'updated_at'}
        if archived:
            params['sourceKinds'] = ['cli', 'vscode', 'exec', 'appServer', 'subAgent',
                                     'subAgentReview', 'subAgentCompact', 'subAgentThreadSpawn',
                                     'subAgentOther', 'unknown']
        if cwd:
            params['cwd'] = cwd
        if cursor:
            params['cursor'] = cursor
        response = client.call('thread/list', params)
        for thread in response.get('data', []):
            items.append({'session_id': thread['id'], 'title': thread.get('name') or thread.get('preview') or '(no title)',
                          'path': thread.get('path'), 'cwd': thread.get('cwd'),
                          'updated_at': datetime.fromtimestamp(thread.get('updatedAt', 0), timezone.utc).isoformat(),
                          'descendants': True})
        cursor = response.get('nextCursor')
        if not cursor:
            return items
        if cursor in seen:
            raise RuntimeError('Repeated pagination cursor')
        seen.add(cursor)


def pi_roots():
    agent = Path(os.environ.get('PI_CODING_AGENT_DIR', str(Path.home() / '.pi/agent'))).resolve()
    settings = agent / 'settings.json'
    data = json.loads(settings.read_text()) if settings.exists() else {}
    configured = Path(data.get('sessionDir') or 'sessions')
    sessions = (agent / configured).resolve()
    # Sibling directory: pi-acp recursively scans its sessions directory.
    return sessions, sessions.parent / 'archived_sessions'


def pi_items(root, cwd=None):
    items = []
    if not root.exists():
        return items
    for directory, dirs, files in os.walk(root, followlinks=False):
        dirs[:] = [d for d in dirs if not (Path(directory) / d).is_symlink()]
        for filename in files:
            path = Path(directory) / filename
            if path.suffix != '.jsonl' or path.is_symlink():
                continue
            try:
                with path.open() as stream:
                    header = json.loads(stream.readline())
                    if header.get('type') != 'session' or not header.get('id'):
                        continue
                    if cwd and header.get('cwd') != cwd:
                        continue
                    title, fallback = None, None
                    for line in stream:
                        try:
                            obj = json.loads(line)
                        except ValueError:
                            continue
                        if obj.get('type') == 'session_info' and obj.get('name'):
                            title = obj['name']
                        message = obj.get('message', {})
                        if not fallback and isinstance(message, dict) and message.get('role') == 'user':
                            content = message.get('content', '')
                            fallback = content if isinstance(content, str) else ' '.join(
                                p.get('text', '') for p in content if isinstance(p, dict) and p.get('type') == 'text')
                items.append({'session_id': header['id'], 'title': title or fallback or '(no title)',
                              'path': str(path), 'cwd': header.get('cwd'),
                              'updated_at': datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat()})
            except (OSError, ValueError):
                continue
    return sorted(items, key=lambda item: item['updated_at'], reverse=True)


def selected(items, request):
    matches = [item for item in items if item['session_id'] == request.get('session_id')]
    if len(matches) != 1:
        raise RuntimeError('Session missing or ambiguous; refresh the list')
    item = matches[0]
    if request.get('path') and item['path'] != request['path']:
        raise RuntimeError('Session path changed; refresh the list')
    return item


def session_in_use(item):
    """Best-effort local detection: open transcript or explicit session argument."""
    transcript = item.get('path')
    session_id = item['session_id'].encode()
    for process in Path('/proc').iterdir():
        if not process.name.isdigit() or int(process.name) == os.getpid():
            continue
        try:
            if process.stat().st_uid != os.getuid():
                continue
            arguments = (process / 'cmdline').read_bytes().split(b'\0')
            if session_id in arguments:
                return True
            if transcript:
                for fd in (process / 'fd').iterdir():
                    try:
                        if os.readlink(fd) == transcript:
                            return True
                    except OSError:
                        pass
        except OSError:
            continue
    return False


def availability(request):
    if request['provider'] == 'codex-acp':
        with Codex() as client:
            items = codex_items(client, False)
    elif request['provider'] == 'pi-acp':
        items = pi_items(pi_roots()[0])
    else:
        return {'available': False}
    item = next((item for item in items if item['session_id'] == request['session_id']), None)
    return {'available': item is not None and not session_in_use(item)}


def execute(request):
    action, provider = request['action'], request['provider']
    if action == 'availability':
        return availability(request)
    if action not in ('list', 'archive', 'unarchive', 'delete'):
        raise ValueError('Unknown action')
    archived = request.get('archived', False) if action == 'list' else action != 'archive'
    if provider == 'codex-acp':
        with Codex() as client:
            items = codex_items(client, archived, request.get('cwd') if action == 'list' else None)
            if action == 'list':
                return {'items': items}
            item = selected(items, request)
            client.call('thread/' + action, {'threadId': item['session_id']})
            return {'ok': True}
    if provider != 'pi-acp':
        raise ValueError('Archive management supports codex-acp and pi-acp')
    sessions, archive = pi_roots()
    root = archive if archived else sessions
    items = pi_items(root, request.get('cwd') if action == 'list' else None)
    if action == 'list':
        return {'items': items}
    item = selected(items, request)
    path = Path(item['path'])
    if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
        raise ValueError('Unsafe session path')
    if action == 'delete':
        path.unlink()
    else:
        destination_root = sessions if archived else archive
        target = destination_root / path.relative_to(root)
        if not target.resolve().is_relative_to(destination_root.resolve()):
            raise ValueError('Unsafe destination')
        target.parent.mkdir(parents=True, exist_ok=True)
        # Exclusive link + unlink: never overwrite an existing session.
        os.link(path, target)
        try:
            path.unlink()
        except OSError:
            target.unlink()
            raise
    return {'ok': True}


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(124))
    try:
        print(json.dumps(execute(json.load(sys.stdin))))
    except Exception as error:
        print(json.dumps({'error': str(error)}))
        sys.exit(1)
