"""Prepare resolution-independent illustrations from their original SVGs.

Run with --research PATH only when rebuilding the 192 starter source choices.
All selected originals are delivered in data/picture_art_sources.
"""
import argparse, hashlib, json, pathlib, shutil
ROOT=pathlib.Path(__file__).resolve().parents[1]
ORIGINALS = {
 'river': '<path fill="#BFE3AD" d="M24 35h208v186H24z"/><path fill="#76C8EC" d="M90 35h68c-70 47 64 86 8 126-16 12-45 21-37 60H54c-13-65 82-71 73-97-9-25-93-49-37-89Z"/><path fill="none" d="M102 52c-35 31 50 53 45 80-5 24-50 36-50 64"/><path fill="#72B76C" d="m39 68 23-35 23 35Zm137 112 23-35 23 35Z"/><path d="M62 69v16m137 95v16"/>',
 'sea': '<path fill="#DFF5FF" d="M24 83h208v137H24z"/><path fill="#73C4EB" d="M24 111c24 0 23-25 48-25s25 25 50 25 25-25 50-25 26 25 60 25v109H24Z"/><path fill="none" stroke="#2189B1" d="M25 146c25 0 24-23 49-23s25 23 50 23 25-23 50-23 26 23 57 23M25 187c25 0 24-23 49-23s25 23 50 23 25-23 50-23 26 23 57 23"/>',
 'lake': '<path fill="#9FD080" d="M25 114 72 65l43 49 47-72 70 84v79H25Z"/><ellipse cx="128" cy="167" rx="103" ry="46" fill="#75CAED"/><path fill="none" stroke="#2189B1" d="M76 165h51m10 20h43m-73-37h51"/><path fill="none" stroke="#4B8B45" d="M42 205v-46m0 27-13-19m13 9 12-19m158 48v-48m0 24 15-14"/>',
 'roof': '<path fill="#E7DBCD" d="M58 132h140v84H58z"/><path fill="#CA7356" d="m25 130 103-94 103 94-17 18-86-76-86 76Z"/><path fill="#CA7356" d="M179 50h26v64l-26-24z"/><path fill="none" d="m86 100 18 15m23-52 16 17m4 20 17 14m13 8 16 14"/><path fill="#CDBDAA" d="M106 174h44v42h-44z"/>',
 'classroom': '<path fill="#75AC9A" d="M35 30h186v104H35z"/><path fill="none" stroke="#FFF" d="M63 66h26m-13-13v26m35-13h29m17-12 23 25m0-25-23 25M63 103h118"/><g fill="#E8BB70"><path d="M31 163h79v24H31zm115 0h79v24h-79zM31 212h79v19H31zm115 0h79v19h-79z"/></g><path d="M43 187v18m55-18v18m60-18v18m55-18v18M43 231v10m55-10v10m60-10v10m55-10v10"/>',
 'mother': '<path fill="#654137" d="M53 95V65c0-51 73-51 73 0v37Z"/><circle cx="90" cy="60" r="29" fill="#F1C29F"/><path fill="#9266B2" d="M54 125c0-47 75-47 75 0l21 93H31Z"/><path fill="none" stroke="#F1C29F" stroke-width="20" d="m62 131 58 33 43-15m-42-26 36 40"/><circle cx="175" cy="124" r="23" fill="#F1C29F"/><path fill="#E5AE54" d="M151 160c12-17 37-17 47 0l13 47h-72Z"/><path fill="none" stroke="#F1C29F" stroke-width="13" d="m150 168-27 8m74-9 24 18"/><path d="M61 218v20m56-20v20m43-31v30m32-30v30"/>',
 'father': '<path fill="#694D37" d="M59 43c3-31 65-32 68 8l-26-10-42 12Z"/><circle cx="92" cy="66" r="29" fill="#F1C29F"/><path fill="#759CB8" d="M51 121c0-42 80-43 80 0v89H51Z"/><path fill="none" stroke="#F1C29F" stroke-width="20" d="m61 128 57 38 44-17m-40-26 36 40"/><circle cx="175" cy="124" r="23" fill="#F1C29F"/><path fill="#E5AE54" d="M151 160c12-17 37-17 47 0l13 47h-72Z"/><path fill="none" stroke="#F1C29F" stroke-width="13" d="m150 168-27 8m74-9 24 18"/><path d="M69 210v29m43-29v29m48-32v30m32-30v30"/>',
 'listen': '<path fill="#F1C29F" d="M51 155V95c0-83 128-84 128 0v64c0 47-76 55-98 17Z"/><path fill="#654137" d="M50 99c-15-86 119-109 130-13-18-26-42-39-71-38-10 24-32 40-59 51Z"/><path fill="none" d="M119 107c25-22 47 20 18 30m-41-35v9m-9 34c9 7 18 7 28 0"/><path fill="none" stroke="#F1C29F" stroke-width="18" d="m181 216-9-54 12-26m-13 24-13-29"/><path fill="none" stroke="#9266B2" d="M199 96c13 14 13 28 0 42m20-55c23 25 23 44 0 69"/>',
 'fan': '<circle cx="128" cy="95" r="73" fill="#E9E1F0"/><path fill="#9271B2" d="M128 91c-65-5-34-68-5-55 24 10 11 36 5 55Zm8 9c38-52 76 7 47 28-22 16-37-9-47-28Zm-14 5c25 60-45 63-49 29-3-26 25-26 49-29Z"/><circle cx="128" cy="95" r="13" fill="#E8BB70"/><path fill="#9271B2" d="M115 168h26v44h-26z"/><path fill="#E9E1F0" d="M84 212h88l17 21H67Z"/>',
}
def svg(body):
 return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256"><g stroke="#423A39" stroke-width="6" stroke-linejoin="round" stroke-linecap="round">'+body+'</g></svg>'
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--research',type=pathlib.Path);args=parser.parse_args()
 manifest=json.loads((ROOT/'data/picture_sources.json').read_text())
 if manifest.get('version','') >= '1.7.0':raise SystemExit('1.7 katalogi uchun mavjud data/picture_art_sources va tools/build_vectors.py dan foydalaning; eski tanlovni qayta yozish to‘xtatildi.')
 folder=ROOT/'data/picture_art_sources';folder.mkdir(exist_ok=True)
 selected=json.loads((ROOT/'data/starter_vector_selection.json').read_text())
 assets={(a['origin'],a['source_file']):a for a in manifest['sources']}
 starter={}
 for word,pair in selected.items():
  origin,name=pair;key=(origin,name)
  if key not in assets:
   aid=origin+'_'+hashlib.sha256(name.encode()).hexdigest()[:16]
   dest=folder/(aid+'.svg')
   if not dest.exists():
    if not args.research:raise SystemExit('Original SVG missing: '+str(dest))
    shutil.copyfile(args.research/(origin+'_svg')/name,dest)
   base={'mulberry':'https://raw.githubusercontent.com/mulberrysymbols/mulberry-symbols/master/EN/', 'openmoji':'https://raw.githubusercontent.com/hfg-gmuend/openmoji/master/color/svg/', 'tabler':'https://raw.githubusercontent.com/tabler/tabler-icons/main/icons/outline/'}[origin]
   assets[key]={'id':aid,'origin':origin,'source_file':name,'url':base+name,
     'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'license':'MIT' if origin=='tabler' else 'CC-BY-SA-4.0'}
  starter[word]='symbols/'+assets[key]['id']
 for word,body in ORIGINALS.items():
  aid='lingoy_'+word;dest=folder/(aid+'.svg');dest.write_text(svg(body))
  assets[('lingoy',aid+'.svg')]={'id':aid,'origin':'lingoy','source_file':aid+'.svg','url':'','sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'license':'MIT'}
  starter[word]='symbols/'+aid
 assert len(starter)==192
 manifest['version']='1.5.0';manifest['sources']=list(assets.values())
 manifest['additional_unique_images']=2499
 manifest['total_vector_files']=len(assets)
 manifest['starter_vector_assets']=starter
 manifest['notes']='5000 unique dictionary entries: 3783 single-word headwords and 1217 phrases. All use precompiled vectors. Synonyms may share a selected-sense image; editorial verification is incomplete.'
 (ROOT/'data/picture_sources.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=1))
 (ROOT/'mobile/assets/starter_vectors.json').write_text(json.dumps(starter,separators=(',',':')))
 print('Vector source files:',len(assets),'Starter:',len(starter))
if __name__=='__main__':main()
