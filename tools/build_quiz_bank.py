"""Build a shared, offline distractor bank from the existing dictionary."""
from pathlib import Path
import json,re,sqlite3
ROOT=Path(__file__).resolve().parents[1]
def build():
    db=sqlite3.connect(ROOT/'mobile/assets/dictionary.db');db.row_factory=sqlite3.Row
    editorial=json.loads((ROOT/'mobile/assets/informal_glosses.json').read_text())
    glosses=json.loads((ROOT/'mobile/assets/base_glosses.json').read_text())['glosses']
    priority=json.loads((ROOT/'mobile/assets/sense_priority.json').read_text())['first_senses']
    examples=json.loads((ROOT/'mobile/assets/sense_examples.json').read_text())['senses']
    def study(lemma,senses,translation):
        groups={}
        for sense in senses:groups.setdefault(sense['pos'],[]).append(sense)
        ranked=[]
        for pos,group in sorted(groups.items(),key=lambda item:0 if priority.get(lemma+':'+item[0]) else 1):
            ranked.extend(sorted(group,key=lambda s:0 if priority.get(lemma+':'+pos)==s['id'] else 1))
        normalize=lambda w:re.sub(r'\s+',' ',w.lower().replace('_',' ')).strip()
        meanings=[]
        for sense in ranked:
            raw=json.loads(sense['words'])
            if not any(normalize(w)==normalize(lemma) for w in raw):continue
            words=[normalize(w) for w in raw if normalize(w)!=normalize(lemma) and normalize(w) and len(w)<=80 and not re.search(r'[<>\n\r{}\[\]]',w)]
            choices=list(dict.fromkeys(words))[:6]
            if not choices:continue
            context=examples.get(sense['id'],{}).get('meaning_uz') or ''
            meanings.append({'id':sense['id'],'pos':sense['pos'],'definition':sense['definition'],'context':context,'choices':choices})
        glosses=[normalize(g) for g in translation.split(';') if normalize(g)]
        def score(s):
            parts={normalize(g) for g in s['context'].split(';')}
            return max([len(glosses)-i+1 for i,g in enumerate(glosses) if g in parts] or [0])
        first=max(meanings,key=score) if meanings else None
        return {'meanings':meanings,'senseId':first['id'] if first else '', 'choices':first['choices'] if first else [],'context':first['context'] if first else ''}
    rows=list(db.execute('select * from entries order by case when level<>\'\' then 0 else 1 end,id'))
    all_words=[r['normalized'] for r in rows]
    pool=[]
    for r in rows:
        lemma=r['normalized'];meaning=editorial.get(lemma) or (r['translation'] if r['translation_source'] in ['LEXORA original editorial','Lingoy original editorial','Lingoy AI definition-aligned editorial'] else '') or next((glosses.get(lemma+':'+p) for p in ['v','n','a','s','r'] if glosses.get(lemma+':'+p)),None) or r['translation']
        if not meaning or not re.fullmatch(r"[a-z]{2,18}(?: [a-z]{1,18}){0,4}",lemma) or '[' in meaning:continue
        senses=list(db.execute('select s.* from senses s join entry_senses e on s.id=e.sense_id where e.entry_id=? order by e.ordinal',(r['id'],)))
        synonyms=sorted({w.lower().replace('_',' ') for s in senses for w in json.loads(s['words']) if w.lower()!=lemma})
        pool.append({'id':r['id'],'lemma':lemma,'translation':meaning,'groups':[s['id'] for s in senses],'synonyms':synonyms,**study(lemma,senses,meaning)})
        if len(pool)>=5500:break
    # Ensure useful confusables and corrected examples are present regardless of CEFR tags.
    have={x['lemma'] for x in pool}
    for lemma in list(editorial)+['large','barge','charge','receive','deceive','perceive','relieve','lullaby','big','huge','enormous']:
        if lemma in have:continue
        r=db.execute('select * from entries where normalized=?',(lemma,)).fetchone()
        if r:
            senses=list(db.execute('select s.* from senses s join entry_senses e on s.id=e.sense_id where e.entry_id=? order by e.ordinal',(r['id'],)))
            pool.append({'id':r['id'],'lemma':lemma,'translation':editorial.get(lemma) or r['translation'],'groups':[s['id'] for s in senses],'synonyms':sorted({w.lower().replace('_',' ') for s in senses for w in json.loads(s['words']) if w.lower()!=lemma}),**study(lemma,senses,editorial.get(lemma) or r['translation'])})
            have.add(lemma)
    # Keep a translated entry for each linked answer, even outside the common-word pool.
    # These words also make the distractor meaning and polysemy checks available offline.
    linked={answer for word in pool for answer in word['choices']}
    for lemma in sorted(linked-have):
        row=db.execute('select * from entries where normalized=?',(lemma,)).fetchone()
        if not row or not row['translation']:continue
        senses=list(db.execute('select s.* from senses s join entry_senses e on s.id=e.sense_id where e.entry_id=? order by e.ordinal',(row['id'],)))
        pool.append({'id':row['id'],'lemma':lemma,'translation':editorial.get(lemma) or row['translation'],'groups':[s['id'] for s in senses],'synonyms':sorted({w.lower().replace('_',' ') for s in senses for w in json.loads(s['words']) if w.lower()!=lemma}),**study(lemma,senses,editorial.get(lemma) or row['translation'])})
        have.add(lemma)
    assert len(pool)==len({w['lemma'] for w in pool}), 'Duplicate option candidates'
    data={'version':2,'entries':pool,'validWords':all_words,'typicalMisspellings':{'receive':['recieve'],'believe':['beleive'],'necessary':['neccessary','necesary'],'separate':['seperate'],'beautiful':['beautifull'],'because':['becuase'],'friend':['freind'],'lullaby':['lalluby'],'accommodation':['accomodation']}}
    target=ROOT/'mobile/assets/quiz_bank.json';target.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n')
    print(json.dumps({'candidates':len(pool),'valid_spellings':len(all_words),'bytes':target.stat().st_size}))
if __name__=='__main__':build()
