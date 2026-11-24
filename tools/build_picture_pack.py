"""Rebuild the bundled compact pictograms. pip install cairosvg pillow"""
import concurrent.futures, hashlib, io, json, pathlib, sys
import cairosvg
from PIL import Image
ROOT=pathlib.Path(__file__).resolve().parents[1]
def render(item):
    src=ROOT/'data/picture_art_sources'/(item['id']+'.svg')
    raw=src.read_bytes()
    if hashlib.sha256(raw).hexdigest()!=item['sha256']:
        raise ValueError('Source checksum mismatch: '+str(src))
    # Tabler uses currentColor; fix a legible ink for the white illustration card.
    raw=raw.replace(b'currentColor',b'#4B356B')
    png=cairosvg.svg2png(bytestring=raw,output_width=256,output_height=256,
                        background_color='#ffffff')
    im=Image.open(io.BytesIO(png)).convert('RGB')
    dst=ROOT/'mobile/assets/pictures/symbols'/(item['id']+'.webp')
    im.save(dst,format='WEBP',quality=82,method=6)
    return dst.stat().st_size
def main():
    manifest=json.loads((ROOT/'data/picture_sources.json').read_text())
    (ROOT/'mobile/assets/pictures/symbols').mkdir(parents=True,exist_ok=True)
    with concurrent.futures.ProcessPoolExecutor(max_workers=4) as pool:
        sizes=list(pool.map(render,manifest['sources'],chunksize=8))
    print(f'{len(sizes)} images; {sum(sizes)/1024/1024:.2f} MiB total')
if __name__=='__main__':main()
