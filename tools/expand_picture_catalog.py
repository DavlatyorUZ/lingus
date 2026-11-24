"""Extend visual entries from publisher keywords and selected WordNet senses.

Input metadata and candidates are prepared in --research. The shipped manifest
records exact source URLs, selected senses, visual labels, license and hashes.
No AI output or nearest-word image fallback is used.
"""
import argparse,collections,hashlib,importlib.util,json,math,pathlib,re,sqlite3,urllib.request,concurrent.futures
ROOT=pathlib.Path(__file__).resolve().parents[1]
def main():
 a=argparse.ArgumentParser();a.add_argument('--research',type=pathlib.Path,required=True);args=a.parse_args();r=args.research.resolve();m=json.loads((ROOT/'data/picture_sources.json').read_text());db=sqlite3.connect(ROOT/'mobile/assets/dictionary.db');db.row_factory=sqlite3.Row
 entries={x['normalized']:dict(x) for x in db.execute('select * from entries')};senses={x['id']:dict(x) for x in db.execute('select * from senses')};by=collections.defaultdict(list)
 for x in db.execute('select * from entry_senses order by ordinal'):by[x['entry_id']].append(senses[x['sense_id']])
 index=json.loads((ROOT/'mobile/assets/picture_index.json').read_text());starter=json.loads((ROOT/'mobile/assets/starter_vectors.json').read_text());existing={x[0] for x in index}|set(starter)
 if len(existing)!=5000:raise SystemExit('Run this extension once on the 5000-entry baseline.')
 sources={x['id']:x for x in m['sources']};pool={};originals={}
 banned=re.compile(r'\b(vagina|penis|sex|sexual|breast|nipple|condom|cocaine|heroin|marijuana|cannabis|nazi|swastika|suicide|cigarette|tobacco|beer|wine|whisky|vodka|cocktail|weapon|gun|rifle|pistol|bomb)\b')
 # Reject known context tags and misleading homonyms; preserve the existing edited mapping.
 reject={'attending','bavaria','coalesce','considerate','drove','looker','polo','roughened','slider','soy','surreptitious','toying','very','cordovan','cordova','zend','approximately','big fish','frailty','loony','shock absorber','white room','ravisher'}
 def eligible(w):return w in entries and w not in existing and len(w)>1 and not banned.search(w) and w not in reject and not re.fullmatch(r'\d+(st|nd|rd|th)?',w)
 def offer(w,record,quality):
  if eligible(w) and (w not in pool or quality>pool[w]['quality']):pool[w]=dict(record,quality=quality)
 def synonyms(c,record,quality):
  for w in json.loads(senses[c['sense']]['words']):offer(w.lower(),dict(record,sense=c['sense']),quality)
 seen=set()
 for origin,file in [('openmoji','cldr_candidates.json'),('mdi','mdi_candidates.json'),('fontawesome','fa_candidates.json')]:
  for w,c in json.loads((r/file).read_text()).items():
   if c['score']<1:continue
   key=(origin,c['word'],c['sense'],c.get('name') or c.get('icon',{}).get('name') or c.get('icon',{}).get('hexcode'))
   if key in seen:continue
   seen.add(key)
   fixed={'tissue':'n15074962','scale':'n4141975','style':'n7066659'}
   if c['word'] in fixed:c=dict(c,sense=fixed[c['word']])
   if origin=='mdi':
    icon=c['icon']
    if any(re.search('brand|logo',t,re.I) for t in icon['tags']):continue
    name=icon['name'];label=c['word'];exact=label==name.replace('-',' ') or label in [x.replace('-',' ') for x in icon['aliases']]
    rec={'origin':origin,'file':name+'.svg','label':label,'category':'Belgilar va buyumlar','url':'https://raw.githubusercontent.com/Templarian/MaterialDesign/master/svg/'+name+'.svg','license':'Apache-2.0'}
   elif origin=='fontawesome':
    name=c['name'];label=c['word'];exact=c['exact'];rec={'origin':origin,'file':name+'.svg','label':label,'category':'Belgilar va buyumlar','url':'https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/svgs/solid/'+name+'.svg','license':'CC-BY-4.0'}
   else:
    icon=c['icon'];name=icon['hexcode'];label=c['word'];exact=label==icon['annotation'].lower();groups={'smileys-emotion':'Hislar va ifodalar','people-body':'Odamlar va harakatlar','animals-nature':'Hayvonlar va tabiat','food-drink':'Taomlar va ichimliklar','travel-places':'Joylar va transport','flags':'Mamlakatlar'}
    rec={'origin':origin,'file':name+'.svg','label':label,'category':groups.get(icon['group'],'Belgilar va buyumlar'),'url':'https://raw.githubusercontent.com/hfg-gmuend/openmoji/master/color/svg/'+name+'.svg','license':'CC-BY-SA-4.0','publisher_label':icon['annotation']}
   rec['association']='publisher-label' if exact else 'publisher-keyword'
   # Metadata terms are a visual association, never evidence of every sense of a word.
   for alias in json.loads(senses[c['sense']]['words']):
    offer(alias.lower(),dict(rec,sense=c['sense']),20+(5 if exact else 0)+min(c['score'],15))
 # Exact numeric diagrams: numbers/counts and ordinals, excluding raw digit entries.
 from fontTools.ttLib import TTFont
 from fontTools.pens.svgPathPen import SVGPathPen
 font=TTFont(ROOT/'mobile/assets/fonts/Manrope.ttf');glyphs=font.getGlyphSet();cmap=font.getBestCmap();hmtx=font['hmtx'];upem=font['head'].unitsPerEm
 def outlined(text,x,y,size):
  body='';scale=size/upem;total=sum(hmtx[cmap[ord(c)]][0] for c in text);cursor=x-total*scale/2
  for c in text:
   pen=SVGPathPen(glyphs);glyphs[cmap[ord(c)]].draw(pen);body+=f'<path d="{pen.getCommands()}" transform="translate({cursor:.3f} {y}) scale({scale:.6f} {-scale:.6f})"/>';cursor+=hmtx[cmap[ord(c)]][0]*scale
  return '<g fill="#655185">'+body+'</g>'
 def base(body):return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256"><rect x="28" y="24" width="200" height="208" rx="28" fill="#FAF6ED" stroke="#E4D6EA" stroke-width="2"/>'+body+'</svg>'
 for sid,s in senses.items():
  ws=json.loads(s['words']);nums=[x for x in ws if re.fullmatch(r'\d+(st|nd|rd|th)?',x)]
  if not nums or s['pos'] not in ['n','a','s']:continue
  number=nums[0];n=int(re.match(r'\d+',number)[0]);ordinal=not number.isdigit();label=number;artid='studio_number_'+number
  dots='';amount=min(n,20)
  if n<=20 and n>0:
   for k in range(amount):
    xx=68+(k%5)*30;yy=151+(k//5)*18;fill='#9D86BF' if ordinal and k+1==n else '#E9BE69'
    dots+=f'<circle cx="{xx}" cy="{yy}" r="5.5" fill="{fill}"/>'
  text=number if len(number)<11 else f'{n:.0e}'.replace('+0','').replace('+','')
  if any(ord(c) not in cmap for c in text):continue
  originals[artid]=base(outlined(text,128,120,min(72,140/max(1,len(text))/.58))+dots)
  for w in ws:
   w=w.lower()
   if re.fullmatch('[ivxlcdm]+',w):continue
   offer(w,{'origin':'lingoy','file':artid+'.svg','label':label,'sense':sid,'category':'Sanoq va tartib','license':'MIT','url':'','association':'exact-numeric-diagram','artid':artid},100)
 # Color swatches use the standard CSS palette, only for explicit color senses.
 from matplotlib.colors import CSS4_COLORS
 for color,rgb in CSS4_COLORS.items():
  for s in by[entries[color]['id']] if color in entries else []:
   if not re.search(r'\bcolo[u]?r\b|\bhue\b|\bchromatic\b',s['definition'],re.I):continue
   if s['pos']=='n' and not re.search(r'colo[u]?r or pigment|colo[u]?r(ing)? |hue',s['definition'],re.I):continue
   artid='studio_color_'+color
   originals[artid]=base(f'<path d="M61 79C93 45 178 49 199 104 219 155 176 209 120 207 66 205 32 128 61 79Z" fill="{rgb}" stroke="#8C7C95" stroke-width="2"/><path d="M78 96q12-19 35-19" fill="none" stroke="#FFF" stroke-opacity=".5" stroke-width="7" stroke-linecap="round"/>')
   for w in json.loads(s['words']):offer(w.lower(),{'origin':'lingoy','file':artid+'.svg','label':color+' (colour)','sense':s['id'],'category':'Ranglar','license':'MIT','url':'','association':'exact-colour-swatch','artid':artid},95)
 # Chemical symbols and atomic numbers are conventional diagrams, not generic initials.
 elements='hydrogen:H helium:He lithium:Li beryllium:Be boron:B carbon:C nitrogen:N oxygen:O fluorine:F neon:Ne sodium:Na magnesium:Mg aluminum:Al silicon:Si phosphorus:P sulfur:S chlorine:Cl argon:Ar potassium:K calcium:Ca scandium:Sc titanium:Ti vanadium:V chromium:Cr manganese:Mn iron:Fe cobalt:Co nickel:Ni copper:Cu zinc:Zn gallium:Ga germanium:Ge arsenic:As selenium:Se bromine:Br krypton:Kr'.split()
 for num,pair in enumerate(elements,1):
  name,symbol=pair.split(':')
  if name not in entries:continue
  ss=[s for s in by[entries[name]['id']] if re.search('element|atomic number',s['definition'])]
  if not ss:continue
  s=ss[0];artid='studio_element_'+symbol.lower();originals[artid]=base(outlined(str(num),128,74,25)+outlined(symbol,128,165,78))
  for w in json.loads(s['words']):offer(w.lower(),{'origin':'lingoy','file':artid+'.svg','label':symbol+' (chemical element)','sense':s['id'],'category':'Kimyo','license':'MIT','url':'','association':'exact-element-symbol','artid':artid},95)
 print('Pool',len(pool),'total possible',len(existing)+len(pool),flush=True)
 if len(pool)<5000:raise SystemExit('Insufficient source-grounded candidate records; no padded catalog written.')
 def priority(kv):
  w,c=kv
  return (-c['quality'],not bool(entries[w]['level']),not bool(entries[w]['translation']),len(w)>30,len(w),w)
 chosen=sorted(pool.items(),key=priority)[:5000]
 # Materialize each original once. Preserve the existing 2629 assets.
 needed={}
 for w,c in chosen:
  aid=c.get('artid') or c['origin']+'_'+hashlib.sha256(c['file'].encode()).hexdigest()[:16];c['asset']=aid
  needed.setdefault(aid,c)
 folder=ROOT/'data/picture_art_sources'
 fa=json.loads((r/'fontawesome.json').read_text());mdifolder=r/'upstream/MaterialDesign-master/svg'
 def obtain(kv):
  aid,c=kv;p=folder/(aid+'.svg')
  if aid in sources:return
  if c['origin']=='lingoy':p.write_text(originals[aid])
  elif c['origin']=='mdi':p.write_bytes((mdifolder/c['file']).read_bytes())
  elif c['origin']=='fontawesome':p.write_text(fa[c['file'][:-4]]['svg']['solid']['raw'])
  elif not p.exists():
   for attempt in range(3):
    try:urllib.request.urlretrieve(c['url'],p);break
    except Exception:
     if attempt==2:raise
  if c['origin'] in ['mdi','fontawesome']:
   # Publisher geometry retained, a coherent violet fill replaces default black.
   text=p.read_text().replace('<path ','<path fill="#80639F" ',1);p.write_text(text)
  return aid,{'id':aid,'origin':c['origin'],'source_file':c['file'],'url':c['url'],
    'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'license':c['license'],
    'art_change':'original diagram' if c['origin']=='lingoy' else 'publisher vector; violet fill for monochrome symbols'}
 with concurrent.futures.ThreadPoolExecutor(8) as ex:
  for result in ex.map(obtain,needed.items()):
   if result:sources[result[0]]=result[1]
 for w,c in chosen:
  s=senses[c['sense']];uz=json.loads(s['uz']);meaning='; '.join(uz[:2]) if uz else c['label']
  index.append([w,meaning,'symbols/'+c['asset'],c['category'],c['sense'],c['label']])
  m['mappings'].append({'word':w,'entry_id':entries[w]['id'],'image':c['asset'],'sense_id':c['sense'],
    'image_label':c['label'],'definition':s['definition'],'association':c['association'],
    'meaning_language':'uz' if uz else 'en','publisher_label':c.get('publisher_label',c['label'])})
 m.update(version='1.7.0',total_entries=10000,additional_entries=9808,total_vector_files=len(sources),sources=list(sources.values()),
   single_word_headwords=sum(' ' not in w for w in existing|{w for w,c in chosen}),
   new_association_counts=dict(collections.Counter(c['association'] for w,c in chosen)),
   notes='10000 distinct dictionary entries; words and phrases counted separately. Synonyms may share a visual. Added publisher-keyword symbols are associative, not pictures of every sense. Games use 192 edited words. No claim of individual human review of all 10000 mappings.')
 (ROOT/'mobile/assets/picture_index.json').write_text(json.dumps(index,ensure_ascii=False,separators=(',',':')))
 (ROOT/'data/picture_sources.json').write_text(json.dumps(m,ensure_ascii=False,indent=1))
 print('Added',len(chosen),'unique source files',len(needed),'total vectors',len(sources),'single words',m['single_word_headwords'])
if __name__=='__main__':main()
