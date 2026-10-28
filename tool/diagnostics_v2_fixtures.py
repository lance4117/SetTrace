"""Isolated verifier fixtures. Source ZIP is read-only; all outputs stay in the project."""
import copy
import hashlib
import json
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parent.parent
source = root / 'docs/qa/local-diagnostics/android-ui/SetTrace-diagnostics-2026-10-24-053107-450-9f75510c403948ca9ad8fb38cadcc32b.zip'
target = root / 'docs/qa/rest-system-sound/fixtures'
target.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(source) as archive:
    original = {name: archive.read(name) for name in archive.namelist()}

def encode(value):
    return json.dumps(value, separators=(',', ':'), ensure_ascii=False).encode('utf-8')

def build(name, change=None, bad_hash=False):
    contents = copy.deepcopy(original)
    manifest = json.loads(contents.pop('manifest.json'))
    manifest['format_version'] = 2
    manifest['process_builds'] = {}
    events = []
    event_paths = sorted(key for key in contents if key.startswith('events/'))
    for path in event_paths:
        rows = [json.loads(line) for line in contents[path].splitlines() if line]
        events.extend(rows)
    new_event = copy.deepcopy(events[0])
    new_event.update(schema_version=2, event_name='rest.audio', module='rest', phase='output',
                     outcome='observed', severity='info', reason_code='none', incident_id=None,
                     attributes={'trigger': 'preview', 'audio_state': 'suppressed',
                                 'sound_condition': 'silent', 'notification_requested': False})
    if change:
        change(new_event)
    contents[event_paths[0]] += encode(new_event) + b'\n'
    events.append(new_event)
    manifest['event_count'] = len(events)
    manifest['events_with_unknown_build'] = len(events)
    for event in events:
        if len(manifest['process_builds']) < 32:
            manifest['process_builds'][event['process_instance']] = None
    manifest['entries'] = [dict(path=path, bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
                           for path, data in contents.items()]
    if bad_hash:
        contents[event_paths[0]] += b'\n'
    contents['manifest.json'] = encode(manifest)
    with zipfile.ZipFile(target / name, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path, data in contents.items():
            archive.writestr(path, data)

build('mixed-v2.zip')
build('unknown-version.zip', lambda event: event.update(schema_version=99))
build('private-sound.zip', lambda event: event['attributes'].update(sound_condition='content://PRIVATE_SOUND'))
build('raw-identity.zip', lambda event: event.update(objects={'rest_alert': 42}))
build('bad-hash.zip', bad_hash=True)
