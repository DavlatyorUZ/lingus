"""Compile all selected original SVGs without raster or precision reduction.

Run from any directory after `flutter pub get`:
    python tools/build_vectors.py
"""
import argparse, json, pathlib, shutil, subprocess, tempfile, os
ROOT=pathlib.Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--flutter',default=shutil.which('flutter'))
    args=parser.parse_args()
    if not args.flutter:raise SystemExit('Flutter SDK PATH ichida topilmadi.')
    manifest=json.loads((ROOT/'data/picture_sources.json').read_text())
    target=ROOT/'mobile/assets/pictures/vectors';target.mkdir(exist_ok=True)
    ids={a['id'] for a in manifest['sources']}
    assert len(ids)==len(manifest['sources'])==manifest['total_vector_files']
    with tempfile.TemporaryDirectory(prefix='lingoy-svg-') as directory:
        for source in manifest['sources']:
            name=source['id']+'.svg'
            shutil.copyfile(ROOT/'data/picture_art_sources'/name,pathlib.Path(directory)/name)
        command=[args.flutter,'--no-version-check','pub','run','vector_graphics_compiler',
                 '--input-dir',directory,'--out-dir',str(target),'--current-color','0xFF4B356B',
                 '--no-use-half-precision-control-points','--concurrency','4']
        if os.name=='nt' and str(args.flutter).lower().endswith('.bat'):command=['cmd','/c',*command]
        subprocess.run(command,cwd=ROOT/'mobile',check=True)
    for path in target.glob('*.svg.vec'):
        if path.name[:-8] not in ids:path.unlink()
    print(f'{len(ids)} original vectors compiled; no fixed pixel-size limit.')
if __name__=='__main__':main()
