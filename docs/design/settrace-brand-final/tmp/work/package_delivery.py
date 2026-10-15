from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parents[2]
files = [root / name for name in ('index.html', 'README.md', 'design-guide.md', 'overview.svg', 'overview.png')]
for directory in ('logo', 'showcase', 'exports/png', 'settrace-icon/layers'):
    files.extend(p for p in (root / directory).iterdir() if p.is_file())
files.extend(p for p in (root / 'settrace-icon').iterdir() if p.is_file())
for name in ('style-report.json', 'package-verification.json', 'visual-review.json',
             'geometry-02-continuous-sets.json', 'geometry-03-interval-set.json',
             'reference-side-by-side.png', 'reference-overlay.png', 'reference-diff.png'):
    files.append(root / 'settrace-icon/tmp/reports' / name)
for name in ('spec.json', 'concept-comparison.json', 'windows-portability-note.md'):
    files.append(root / 'settrace-icon/tmp/work' / name)
for name in ('geometry.json', 'typography.json', 'small-size-review.png', 'prepare.mjs', 'present.mjs', 'check_delivery.py'):
    files.append(root / 'tmp/work' / name)
files.append(root / 'tmp/reports/delivery-checks.json')
files = sorted(set(files))
assert all(p.is_file() for p in files)
verification = json.loads((root / 'settrace-icon/tmp/reports/package-verification.json').read_text(encoding='utf-8'))
assert verification['status'] == 'ok' and not verification['failures'] and not verification['warnings']
manifest = {'version': '1.0', 'date': '2026-10-15', 'verification_status': 'ok', 'native_platform_package': False,
            'files': [{'path': p.relative_to(root).as_posix(), 'bytes': p.stat().st_size,
                       'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in files]}
manifest_path = root / 'assets-manifest.json'
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
files.append(manifest_path)
zip_path = root / 'SetTrace-Brand-Final.zip'
with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for file in files:
        archive.write(file, 'SetTrace-Brand-Final/' + file.relative_to(root).as_posix())
with zipfile.ZipFile(zip_path) as archive:
    assert archive.testzip() is None
    for item in manifest['files']:
        assert hashlib.sha256(archive.read('SetTrace-Brand-Final/' + item['path'])).hexdigest() == item['sha256']
print(json.dumps({'zip': str(zip_path), 'file_count': len(files), 'bytes': zip_path.stat().st_size,
                  'integrity': 'ok', 'no_runtime_dependencies_in_archive': True}))
