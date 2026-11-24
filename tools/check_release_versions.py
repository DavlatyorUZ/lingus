"""Fail packaging when a visible app version or download belongs to another release."""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]

def check():
    version = json.loads((ROOT / 'server/package.json').read_text())['version']
    assert json.loads((ROOT / 'web/package.json').read_text())['version'] == version
    pubspec = (ROOT / 'mobile/pubspec.yaml').read_text()
    mobile_version, build = re.search(r'^version: (\S+)\+(\d+)$', pubspec, re.M).groups()
    assert mobile_version == version
    constants = (ROOT / 'mobile/lib/core/release.dart').read_text()
    assert f"const appVersion = '{version}';" in constants
    assert f'const appBuild = {build};' in constants
    web = json.loads((ROOT / 'web/dist/release.json').read_text())
    download = json.loads((ROOT / 'downloads/release.json').read_text())
    assert web['version'] == download['version'] == version
    assert int(download['build']) == int(build)
    assert (ROOT / 'web/dist' / web['quizBank'].lstrip('/')).is_file()
    for name in ['server', 'web']:
        lock = json.loads((ROOT / name / 'package-lock.json').read_text())
        assert lock['version'] == lock['packages']['']['version'] == version
    return {'version': version, 'build': int(build), 'web_mobile_downloads': 'consistent'}

if __name__ == '__main__':
    print(json.dumps(check()))
