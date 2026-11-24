import sqlite3,pathlib,re,json,shutil
root=pathlib.Path(__file__).resolve().parents[1];db=sqlite3.connect(root/'data/dictionary.db')
try:db.execute('ALTER TABLE entries ADD COLUMN ipa TEXT NOT NULL DEFAULT ""')
except sqlite3.OperationalError:pass
m={'AA':'ɑ','AE':'æ','AH':'ʌ','AO':'ɔ','AW':'aʊ','AY':'aɪ','B':'b','CH':'tʃ','D':'d','DH':'ð','EH':'ɛ','ER':'ɝ','EY':'eɪ','F':'f','G':'ɡ','HH':'h','IH':'ɪ','IY':'i','JH':'dʒ','K':'k','L':'l','M':'m','N':'n','NG':'ŋ','OW':'oʊ','OY':'ɔɪ','P':'p','R':'ɹ','S':'s','SH':'ʃ','T':'t','TH':'θ','UH':'ʊ','UW':'u','V':'v','W':'w','Y':'j','Z':'z','ZH':'ʒ'}
rows=[];seen=set()
for ln in open(root/'data/cmu-cmudict.dict'):
 t=ln.strip().split();word=t[0]
 if '(' in word or word in seen:continue
 seen.add(word);ipa=''
 for token in t[1:]:
  if token.startswith('#'):break
  ph=re.sub('[012]','',token);value=m.get(ph,'')
  if token=='AH0':value='ə'
  if token=='ER0':value='ɚ'
  if token.endswith('1'):value='ˈ'+value
  elif token.endswith('2'):value='ˌ'+value
  ipa+=value
 # Broad phonemic rendering: stress marks kept next to vowels, not syllabified.
 rows.append(('/'+ipa+'/',word))
db.executemany('UPDATE entries SET ipa=? WHERE lemma=?',rows);db.commit()
c=db.execute('SELECT count(*) FROM entries WHERE ipa<>""').fetchone()[0];db.execute('INSERT OR REPLACE INTO metadata VALUES(?,?)',('phonetic_entries',str(c)));db.commit();db.execute('VACUUM');db.close()
st=json.load(open(root/'data/coverage.json'));st['phonetic_entries']=c;(root/'data/coverage.json').write_text(json.dumps(st,ensure_ascii=False,indent=2))
shutil.copy2(root/'data/dictionary.db',root/'mobile/assets/dictionary.db');shutil.copy2(root/'data/coverage.json',root/'mobile/assets/coverage.json')
print('Pronunciation entries',c)
