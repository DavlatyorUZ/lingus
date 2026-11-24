"""Export the complete existing dictionary and editorial lessons for offline PWA use."""
from pathlib import Path
import sqlite3,json,gzip,re,ast
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'web/dist/data';OUT.mkdir(parents=True,exist_ok=True)
def write(name,data,compressed=False):
 b=json.dumps(data,ensure_ascii=False,separators=(',',':')).encode();(OUT/name).write_bytes(gzip.compress(b,compresslevel=9,mtime=0) if compressed else b)
c=sqlite3.connect(ROOT/'mobile/assets/dictionary.db');c.row_factory=sqlite3.Row
glosses=json.loads((ROOT/'mobile/assets/base_glosses.json').read_text())['glosses'];slang=json.loads((ROOT/'server/src/slang.json').read_text())
words=[dict(r) for r in c.execute('SELECT * FROM entries ORDER BY id')]
for w in words:
 curated=slang.get(w['lemma']) or (w['translation'] if w['translation_source'] in ['LEXORA original editorial','Lingoy original editorial','Lingoy AI definition-aligned editorial'] else '') or next((glosses[w['lemma']+':'+pos] for pos in ['v','n','a','s','r'] if w['lemma']+':'+pos in glosses),None)
 w['translation']=curated or w['translation']
packages=[]
def package(store,rows):
 for start in range(0,len(rows),10000):
  name=f'{store}-{start//10000:03d}.json.gz';chunk=rows[start:start+10000];write(name,chunk,True);packages.append({'url':'/data/'+name,'store':store,'count':len(chunk)})
package('words',words)
examples=json.loads((ROOT/'mobile/assets/sense_examples.json').read_text())['senses'];senses={r['id']:dict(r) for r in c.execute('SELECT * FROM senses')}
for sid,s in senses.items():s['meaning_uz']=examples.get(sid,{}).get('meaning_uz','');s['bilingual_examples']=json.dumps(examples.get(sid,{}).get('examples',[]),ensure_ascii=False)
links={}
for wid,sid in c.execute('SELECT entry_id,sense_id FROM entry_senses ORDER BY entry_id,ordinal'):links.setdefault(wid,[]).append(senses[sid])
priority=json.loads((ROOT/'mobile/assets/sense_priority.json').read_text())['first_senses']
for w in words:
 groups={}
 for s in links.get(w['id'],[]):groups.setdefault(s['pos'],[]).append(s)
 for pos,group in groups.items():group.sort(key=lambda s:0 if priority.get(w['normalized']+':'+pos)==s['id'] else 1)
 links[w['id']]=[s for pos,group in sorted(groups.items(),key=lambda item:0 if priority.get(w['normalized']+':'+item[0]) else 1) for s in group]
package('details',[{'id':w['id'],'word':w,'senses':links.get(w['id'],[])} for w in words])
write('offline-manifest.json',{'version':json.loads((ROOT/'web/package.json').read_text())['version'],'dictionaryRevision':json.loads((ROOT/'mobile/assets/dictionary_revision.json').read_text())['sha256']+':meanings-v3','entries':len(words),'packages':packages})
p=json.loads((ROOT/'mobile/assets/photo_index.json').read_text());photos={w:'/'+p['assets'][key]['asset'] for w,key in p['words'].items()}
for row in json.loads((ROOT/'mobile/assets/picture_index.json').read_text()):
 name=row[2].split('/')[-1]
 if (ROOT/f'data/picture_art_sources/{name}.svg').exists():photos.setdefault(row[0],f'/assets/vectors/{name}.svg')
write('photos.json',photos);write('essentials.json',json.loads((ROOT/'mobile/assets/collections/essentials.json').read_text()))
source=(ROOT/'mobile/lib/screens/grammar.dart').read_text().split('const lessons = ',1)[1].split('\n];',1)[0]+']'
tokens=re.findall(r"'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"|\bLesson\b|\bQuestion\b|\d+|[\[\](),]",source);position=0
def parse():
 global position
 t=tokens[position];position+=1
 if t=='[':
  values=[]
  while tokens[position]!=']':
   if tokens[position]==',':position+=1
   else:values.append(parse())
  position+=1;return values
 if t in ('Lesson','Question'):
  assert tokens[position]=='(';position+=1;args=[]
  while tokens[position]!=')':
   if tokens[position]==',':position+=1
   else:args.append(parse())
  position+=1;keys=['id','title','level','rule','explanation','examples','mistake','questions'] if t=='Lesson' else ['text','options','answer'];assert len(keys)==len(args);return dict(zip(keys,args))
 if t[0] in ('"',"'"):return ast.literal_eval(t)
 return int(t)
lessons=parse();write('lessons.json',lessons);print(json.dumps({'entries':len(words),'lessons':len(lessons),'illustrations':len(photos),'offline_bytes':sum(f.stat().st_size for f in OUT.glob('*.gz'))}))
