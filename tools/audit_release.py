"""Verify a Lingoy APK against this exact source tree; standard Python only."""
import hashlib, json, pathlib, re, sqlite3, sys, zipfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
def sha(b):return hashlib.sha256(b).hexdigest()
def audit(apk):
    mobile=ROOT/'mobile'
    manifest=json.loads((ROOT/'data/picture_sources.json').read_text())
    index=json.loads((mobile/'assets/picture_index.json').read_text())
    source=(mobile/'lib/core/illustrations.dart').read_text().split('final List<PictureWord>')[0]
    starter=re.findall(r'PictureWord\(\s*"([^\"]+)"',source)
    assert len(starter)==192
    names=starter+[r[0] for r in index]
    assert len(names)==len(set(names))==10000
    assert len(index)==len(manifest['mappings'])==9808
    db=sqlite3.connect(mobile/'assets/dictionary.db')
    assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
    entries={r[0]:r[1] for r in db.execute('SELECT normalized,id FROM entries')}
    assert all(n in entries for n in names)
    for r in manifest['mappings']:
        assert entries[r['word']]==r['entry_id']
        words=json.loads(db.execute('SELECT words FROM senses WHERE id=?',(r['sense_id'],)).fetchone()[0])
        assert r['word'] in [w.lower() for w in words]
    assert len(manifest['sources']) == len({a['id'] for a in manifest['sources']}) == manifest['total_vector_files']
    for a in manifest['sources']:
        assert sha((ROOT/'data/picture_art_sources'/(a['id']+'.svg')).read_bytes())==a['sha256']
    pubspec=(mobile/'pubspec.yaml').read_text()
    declared=re.findall(r'^    - (assets/[^\n]+)$',pubspec,re.M)
    declared+=re.findall(r'^\s+- asset:\s+(assets/[^\n]+)$',pubspec,re.M)
    runtime_files=[]
    for relative in declared:
        path=mobile/relative
        runtime_files.extend(p for p in path.iterdir() if p.is_file()) if path.is_dir() else runtime_files.append(path)
    starter_vectors=json.loads((mobile/'assets/starter_vectors.json').read_text())
    picture_assets={f"assets/pictures/vectors/{value.split('/')[-1]}.svg.vec" for value in starter_vectors.values()}
    picture_assets.update(f"assets/pictures/vectors/{row[2].split('/')[-1]}.svg.vec" for row in index)
    assert len(picture_assets)==manifest['total_vector_files']==4265
    with zipfile.ZipFile(apk) as z:
        assert z.testzip() is None
        assert 'assets/flutter_assets/fonts/MaterialIcons-Regular.otf' in z.namelist()
        for p in runtime_files:
            name='assets/flutter_assets/'+p.relative_to(mobile).as_posix()
            assert sha(z.read(name))==sha(p.read_bytes()),name
        abi=sorted({n.split('/')[1] for n in z.namelist() if n.startswith('lib/')})
        assert abi==['arm64-v8a'],abi
        assert not any('/assets/pictures/' in n and not n.endswith(('.svg.vec','.webp')) for n in z.namelist())
        for asset in picture_assets:assert 'assets/flutter_assets/'+asset in z.namelist(),asset
        assert len([n for n in z.namelist() if '/pictures/vectors/' in n])==4265
    photos=json.loads((mobile/'assets/photo_index.json').read_text())
    assert all(k in photos['assets'] for k in photos['words'].values())
    assert set(starter).issubset(photos['words']), 'All 192 course words require photographic images'
    assert {p.name for p in (mobile/'assets/pictures/photos').glob('*.webp')} == {pathlib.Path(a['asset']).name for a in photos['assets'].values()}
    for a in photos['assets'].values():
        assert a['width'] >= 600 or a['height'] >= 600
        assert a['credit'] and a['license'] and a['source']
        assert sha((mobile/a['asset']).read_bytes())==a['sha256']
    assert pathlib.Path(apk).stat().st_size <= 100_000_000
    return {'photo_files':len(photos['assets']), 'photographic_words':len(photos['words']), 'version':re.search(r'^version:\s*(\S+)',pubspec,re.M).group(1),'apk_bytes':pathlib.Path(apk).stat().st_size,
            'apk_sha256':sha(pathlib.Path(apk).read_bytes()),
            'illustrated_entries':10000,'starter_entries':192,'new_entries':9808,
            'single_word_headwords':sum(' ' not in n for n in names),'phrases':sum(' ' in n for n in names),
            'vector_picture_files':manifest['total_vector_files'],'verified_runtime_files':len(runtime_files),
            'abi':abi,'dictionary_integrity':'ok','all_mapping_sense_memberships':'verified',
            'all_source_svg_checksums':'verified','all_runtime_asset_checksums':'verified'}
if __name__=='__main__':print(json.dumps(audit(sys.argv[1]),indent=2))
