"""Reproducible, sense-aligned PWN 3.0 + UzWordnet + CEFR-J/Octanove ingestion."""
import sqlite3, json, csv, re, html, pathlib, collections, hashlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
def norm(s):
 return re.sub(r'\s+',' ',s.lower().replace('_',' ').translate(str.maketrans({'‘':"'",'’':"'",'ʻ':"'",'ʼ':"'",'`':"'",'ğ':"g'",'ö':"o'",'ş':'sh','ç':'ch'}))).strip()
levels={}
for file in ['cefrj.csv','octanove.csv']:
 for r in csv.DictReader(open(ROOT/'data'/file,encoding='utf-8-sig')):
  lv=r['CEFR'].strip()
  if lv not in ['A1','A2','B1','B2','C1','C2']: continue
  for word in r['headword'].split('/'):
   k=norm(word)
   if k not in levels or lv<levels[k][0]:levels[k]=(lv,'CEFR-J 1.5' if file=='cefrj.csv' else 'Octanove 1.0')
uz=json.load(open(ROOT/'data/uzwordnet.json'))['@graph'][0]
uzs=collections.defaultdict(list)
for e in uz['entry']:
 w=html.unescape(e['lemma']['writtenForm']).replace('_',' ')
 for s in e['sense']:
  _,offset,p=s['synsetRef'].split('-');uzs[p+str(int(offset))].append(w)
senses={};lemmas=collections.defaultdict(list);ants=[]
for pos in ['noun','verb','adj','adv']:
 for line in open(ROOT/'data'/'wordnet'/('data.'+pos)):
  if not line or line.startswith(' '):continue
  parts,gloss=line.rstrip().split('|',1);t=parts.split();p=t[2];p='a' if p=='s' else p;sid=p+str(int(t[0]));n=int(t[3],16);words=[t[4+i*2].replace('_',' ').replace('(a)','').replace('(p)','').replace('(ip)','') for i in range(n)];idx=4+2*n;pc=int(t[idx]);idx+=1
  antonyms=[]
  for i in range(pc):
   symbol,target,tp,source=t[idx:idx+4];idx+=4
   if symbol=='!':antonyms.append(('a' if tp=='s' else tp)+str(int(target)))
  ex=re.findall(r'"([^\"]+)"',gloss);definition=re.sub(r';?\s*"[^\"]*"','',gloss).strip(' ;')
  translated=list(dict.fromkeys(uzs.get(sid,[])))
  senses[sid]={'pos':p,'definition':definition,'examples':ex,'words':words,'uz':translated,'ant':antonyms}
  for w in words:
   k=norm(w)
   if sid not in lemmas[k]:lemmas[k].append(sid)
# Original essential function words absent in WordNet.
essential={'a':('bir; noaniq artikl','Used before a singular countable noun.'),'an':('bir; noaniq artikl','Used before a singular noun beginning with a vowel sound.'),'the':('aniq artikl','Used to identify a particular person or thing.'),'I':('men','The person who is speaking.'),'you':('siz; sen','The person being spoken to.'),'he':('u (erkak)','A male person already mentioned.'),'she':('u (ayol)','A female person already mentioned.'),'it':('u; bu','A thing or animal already mentioned.'),'we':('biz','The speaker and one or more other people.'),'they':('ular','People or things already mentioned.'),'my':('mening','Belonging to the person speaking.'),'your':('sizning; sening','Belonging to the person being spoken to.'),'our':('bizning','Belonging to the speaker and others.'),'their':('ularning','Belonging to people or things already mentioned.'),'and':('va','Used to connect words or clauses.'),'but':('lekin; ammo','Used to introduce a contrasting idea.'),'or':('yoki','Used to introduce an alternative.'),'because':('chunki','For the reason that.'),'if':('agar','On the condition that.'),'of':('ning; dan','Expresses a relationship between things.'),'to':('ga; tomon','Indicates direction or an infinitive.'),'from':('dan','Indicates the starting point.'),'with':('bilan','Accompanied by.'),'without':('siz; ... bo‘lmasdan','Not having or accompanied by.'),'in':('ichida; da','Inside a place or period.'),'on':('ustida; da','In contact with a surface.'),'at':('da; yonida','Indicates a place or time.'),'for':('uchun','Indicates a purpose or recipient.'),'this':('bu','Identifies a nearby person or thing.'),'that':('u; o‘sha','Identifies a person or thing already mentioned.'),'these':('bular','The plural form of this.'),'those':('ular; o‘shalar','The plural form of that.'),'who':('kim','Asks about a person.'),'what':('nima','Asks for information about something.'),'where':('qayerda','Asks about a place.'),'when':('qachon','Asks about a time.'),'why':('nima uchun; nega','Asks about a reason.'),'how':('qanday','Asks about a manner or method.')}
for w,(u,d) in essential.items():
 k=norm(w);sid='original:'+k;senses[sid]={'pos':'function','definition':d,'examples':[],'words':[w],'uz':[u],'ant':[]};lemmas[k].insert(0,sid)
 levels.setdefault(k,('A1','LEXORA original editorial'))
# Independently authored supplementary translations of common learner words.
curated={'learn':'o‘rganmoq','learning':'o‘rganish','beautiful':'chiroyli; go‘zal','achieve':'erishmoq','achievement':'yutuq; erishilgan natija','happy':'baxtli; xursand','good':'yaxshi','bad':'yomon','big':'katta','small':'kichik','important':'muhim','understand':'tushunmoq','improve':'yaxshilamoq; rivojlantirmoq','create':'yaratmoq','speak':'gapirmoq','listen':'tinglamoq','read':'o‘qimoq','write':'yozmoq','eat':'yemoq','drink':'ichmoq','sleep':'uxlamoq','go':'bormoq','come':'kelmoq','study':'o‘qimoq; o‘rganmoq','work':'ish; ishlamoq','travel':'sayohat qilmoq','remember':'eslamoq; yodda tutmoq','forget':'unutmoq','think':'o‘ylamoq','know':'bilmoq','want':'xohlamoq','need':'kerak bo‘lmoq','help':'yordam bermoq','love':'sevmoq; sevgi','new':'yangi','old':'eski; qari','young':'yosh','easy':'oson','difficult':'qiyin','different':'turli; boshqacha','same':'bir xil','free':'bepul; erkin','possible':'mumkin','quickly':'tez','slowly':'sekin','always':'har doim','never':'hech qachon','often':'tez-tez','sometimes':'ba’zan','today':'bugun','tomorrow':'ertaga','yesterday':'kecha','early':'erta','late':'kech','confident':'o‘ziga ishongan','resilient':'qiyinchilikka bardoshli; tiklanuvchan','curious':'qiziquvchan','grateful':'minnatdor','kind':'mehribon','brave':'jasur','honest':'halol; rostgo‘y','patient':'sabrli','fluently':'ravon','carefully':'ehtiyotkorlik bilan','develop':'rivojlantirmoq','discover':'kashf etmoq','explore':'o‘rganib chiqmoq','choose':'tanlamoq','decide':'qaror qilmoq','explain':'tushuntirmoq','practice':'mashq; mashq qilmoq','pronunciation':'talaffuz','vocabulary':'so‘z boyligi','grammar':'grammatika','english':'ingliz tili; inglizcha','language':'til','opportunity':'imkoniyat','knowledge':'bilim','experience':'tajriba','success':'muvaffaqiyat','challenge':'qiyinchilik; sinov','goal':'maqsad','mistake':'xato','question':'savol','answer':'javob','friend':'do‘st','family':'oila','teacher':'o‘qituvchi','student':'o‘quvchi; talaba','school':'maktab','university':'universitet','book':'kitob','water':'suv','food':'ovqat','home':'uy','city':'shahar','country':'mamlakat','time':'vaqt','day':'kun','night':'tun','morning':'ertalab; tong','world':'dunyo','life':'hayot','health':'salomatlik','nature':'tabiat','environment':'atrof-muhit','technology':'texnologiya','science':'fan','research':'tadqiqot','education':'ta’lim','culture':'madaniyat','museum':'muzey','music':'musiqa','art':'san’at','history':'tarix','future':'kelajak','money':'pul','price':'narx','pay':'to‘lamoq','buy':'sotib olmoq','sell':'sotmoq'}
curated.update(json.loads((ROOT/'data'/'editorial.json').read_text(encoding='utf-8')))
# Store curated headword translations separately; do not claim sense-specific alignment.
path=ROOT/'data'/'dictionary.db';path.unlink(missing_ok=True);db=sqlite3.connect(path)
db.executescript('''PRAGMA page_size=4096; PRAGMA journal_mode=OFF; CREATE TABLE senses(id TEXT PRIMARY KEY,pos TEXT,definition TEXT,examples TEXT,words TEXT,uz TEXT,antonyms TEXT);CREATE TABLE entries(id INTEGER PRIMARY KEY,lemma TEXT UNIQUE,normalized TEXT,level TEXT,level_source TEXT,translation TEXT,translation_source TEXT);CREATE TABLE entry_senses(entry_id INTEGER,sense_id TEXT,ordinal INTEGER,PRIMARY KEY(entry_id,sense_id));CREATE TABLE morph(form TEXT,lemma TEXT);CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT);''')
db.executemany('INSERT INTO senses VALUES(?,?,?,?,?,?,?)',[(k,s['pos'],s['definition'],json.dumps(s['examples'],ensure_ascii=False),json.dumps(s['words'],ensure_ascii=False),json.dumps(s['uz'],ensure_ascii=False),json.dumps(s['ant'])) for k,s in senses.items()])
entryrows=[];links=[];search=[]
for i,(k,sids) in enumerate(sorted(lemmas.items()),1):
 trans=list(dict.fromkeys(w for sid in sids for w in senses[sid]['uz']))
 translation=curated.get(k,'; '.join(trans[:12]));lv,ls=levels.get(k,('',''))
 entryrows.append((i,k,k,lv,ls,translation,'LEXORA original editorial' if k in curated else 'UzWordnet 1.0' if trans else ''))
 for n,sid in enumerate(sids):links.append((i,sid,n))
 search.append((i,k,norm(translation)))
db.executemany('INSERT INTO entries VALUES(?,?,?,?,?,?,?)',entryrows);db.executemany('INSERT INTO entry_senses VALUES(?,?,?)',links)
db.executescript('CREATE INDEX idx_normalized ON entries(normalized); CREATE INDEX idx_level ON entries(level,translation);CREATE INDEX idx_sense_entry ON entry_senses(sense_id);CREATE VIRTUAL TABLE search USING fts4(lemma,translation, tokenize=unicode61);')
db.executemany('INSERT INTO search(docid,lemma,translation) VALUES(?,?,?)',search)
for p in ['noun','verb','adj','adv']:
 for ln in open(ROOT/'data'/'wordnet'/(p+'.exc')):
  t=ln.split();db.executemany('INSERT INTO morph VALUES(?,?)',[(norm(t[0]),norm(b)) for b in t[1:]])
db.execute('CREATE INDEX idx_morph ON morph(form)')
stats={'schema':1,'entries':len(entryrows),'senses':len(senses),'translated_entries':sum(bool(r[5]) for r in entryrows),'leveled_entries':sum(bool(r[3]) for r in entryrows),'editorial_entries':sum(r[6]=='LEXORA original editorial' for r in entryrows),'levels':dict(collections.Counter(r[3] for r in entryrows)), 'source_note':'English headwords and multiword expressions. Uzbek coverage is partial; missing CEFR remains unassigned. UzWordnet source quality is not a claim of editorial verification.'}
for k,v in stats.items():db.execute('INSERT INTO metadata VALUES(?,?)',(k,json.dumps(v,ensure_ascii=False)))
db.commit();db.execute('VACUUM');assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok';db.close()
(ROOT/'data'/'coverage.json').write_text(json.dumps(stats,ensure_ascii=False,indent=2));print(json.dumps(stats,ensure_ascii=False));print('DB bytes',path.stat().st_size,'sha256',hashlib.sha256(path.read_bytes()).hexdigest())
