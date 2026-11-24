"""Restore the exact release's large resources without putting binaries in Git."""
from __future__ import annotations
import argparse, hashlib, json, os, shutil, tempfile, urllib.request, zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]

def checksum(path: Path) -> str:
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def restore(archive: Path, manifest: dict, root: Path) -> int:
    if checksum(archive) != manifest['sha256']:
        raise ValueError('Arxiv SHA-256 mos emas. Shu versiyaning Release faylini tanlang.')
    count = 0
    with zipfile.ZipFile(archive) as bundle:
        for item in bundle.infolist():
            path = PurePosixPath(item.filename)
            if path.is_absolute() or '..' in path.parts:
                raise ValueError('Arxivdagi yo‘l xavfsiz emas.')
            if item.is_dir() or not path.parts or path.parts[0] != 'Lingoy':
                continue
            relative = PurePosixPath(*path.parts[1:]).as_posix()
            if not (relative.startswith(tuple(manifest['resource_roots'])) or relative in manifest['binary_paths']):
                continue
            target = root / relative
            if target.exists():
                with bundle.open(item) as source, target.open('rb') as current:
                    expected = hashlib.file_digest(source, 'sha256').digest()
                    actual = hashlib.file_digest(current, 'sha256').digest()
                if expected != actual:
                    raise ValueError(f'Mahalliy fayl o‘zgargan: {relative}. Avval alohida saqlang.')
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            handle, temporary = tempfile.mkstemp(prefix='.' + target.name, suffix='.tmp', dir=target.parent)
            try:
                with os.fdopen(handle, 'wb') as output, bundle.open(item) as source:
                    shutil.copyfileobj(source, output, 1024 * 1024)
                Path(temporary).chmod((item.external_attr >> 16 & 0o777) or 0o644)
                os.replace(temporary, target)
            finally:
                Path(temporary).unlink(missing_ok=True)
            count += 1
    return count

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, help='Oldindan yuklangan server Release ZIP')
    args = parser.parse_args()
    manifest = json.loads((ROOT/'tools/resource_bundle.json').read_text())
    archive = args.archive
    if archive is None:
        archive = ROOT/'.cache'/f'Lingoy_Server_{manifest["version"]}.zip'
        archive.parent.mkdir(parents=True, exist_ok=True)
        if not archive.exists():
            temporary = archive.with_suffix('.download')
            try:
                request = urllib.request.Request(manifest['url'], headers={'User-Agent':'Lingoy-resource-bootstrap'})
                with urllib.request.urlopen(request, timeout=60) as response, temporary.open('wb') as output:
                    shutil.copyfileobj(response, output, 1024 * 1024)
                if checksum(temporary) != manifest['sha256']:
                    raise ValueError('Yuklangan arxiv buzilgan yoki boshqa versiyaga tegishli.')
                temporary.replace(archive)
            finally:
                temporary.unlink(missing_ok=True)
    count = restore(archive, manifest, ROOT)
    print(f'Lingoy {manifest["version"]}: {count} ta resurs tiklandi. SHA-256 tasdiqlandi.')

if __name__ == '__main__':
    main()
