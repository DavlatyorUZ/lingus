"""Audit every entry and atomically apply schema-checked, definition-anchored enrichment."""
from pathlib import Path
import csv,json,sqlite3,hashlib,re
ROOT=Path(__file__).resolve().parents[1]
def audit(apply=False):
    release_version=json.loads((ROOT/'server/package.json').read_text())['version']
    release_tag=release_version.replace('.','_')
    db=sqlite3.connect(ROOT/'mobile/assets/dictionary.db');db.row_factory=sqlite3.Row
    manual=json.loads((ROOT/'mobile/assets/informal_glosses.json').read_text())
    before=list(db.execute('SELECT id,normalized,translation,translation_source FROM entries'))
    protected={r['id'] for r in before if r['normalized'] in manual or 'original editorial' in r['translation_source']}
    missing={r['id'] for r in before if not r['translation']}
    enriched=[];register_rechecks=0;common_rechecks=0;cache=ROOT/'data/dictionary-curation.sqlite'
    if cache.exists():
        with sqlite3.connect(cache) as source:
            enriched=source.execute("SELECT id,translation FROM translations WHERE status='translated'").fetchall()
            if source.execute("SELECT 1 FROM sqlite_master WHERE name='reviews'").fetchone():register_rechecks=source.execute('SELECT count(*) FROM reviews').fetchone()[0]
            if source.execute("SELECT 1 FROM sqlite_master WHERE name='common_reviews'").fetchone():common_rechecks=source.execute('SELECT count(*) FROM common_reviews').fetchone()[0]
    available={r['id'] for r in before};accepted={i:t for i,t in enriched if i in available and i not in protected and isinstance(t,str) and t.strip() and len(t)<=600 and not any('\u0400'<=c<='\u04ff' for c in t)}
    by_id={r['id']:r for r in before}
    key=lambda s:re.sub('[^a-z0-9]','',s.lower())
    echoes={i for i,t in enriched if i in by_id and ' ' in by_id[i]['normalized'] and key(t)==key(by_id[i]['normalized']) and i not in protected}
    accepted={i:t for i,t in accepted.items() if i not in echoes}
    glosses=json.loads((ROOT/'mobile/assets/base_glosses.json').read_text())['glosses']
    preserved_glosses=0
    for i,t in list(accepted.items()):
        lemma=by_id[i]['normalized']
        curated=[glosses[lemma+':'+pos] for pos in ['n','v','a','s','r'] if lemma+':'+pos in glosses]
        if curated:
            parts=[]
            for part in ';'.join(curated+[t]).split(';'):
                part=part.strip()
                if part and part.casefold() not in {x.casefold() for x in parts}:parts.append(part)
            accepted[i]='; '.join(parts);preserved_glosses+=1
    changes=0
    if apply:
        with db:
            for i,t in accepted.items():
                old=db.execute('SELECT translation FROM entries WHERE id=?',(i,)).fetchone()[0]
                if old!=t:
                    db.execute('UPDATE entries SET translation=?,translation_source=? WHERE id=?',(t,'Lingoy AI definition-aligned editorial',i));db.execute('UPDATE search SET translation=? WHERE docid=?',(t,i));changes+=1
            for serial,(word,t) in enumerate(sorted(manual.items())):
                row=db.execute('SELECT id,translation,translation_source FROM entries WHERE normalized=?',(word,)).fetchone()
                if row is None:
                    new_id=max(2000000000,db.execute('SELECT coalesce(max(id),0) FROM entries WHERE id>=2000000000').fetchone()[0]+1)
                    db.execute('INSERT INTO entries(id,lemma,normalized,level,level_source,translation,translation_source,ipa) VALUES(?,?,?,?,?,?,?,?)',(new_id,word,word,'','','%s'%t,'Lingoy original editorial',''))
                    db.execute('INSERT INTO search(docid,lemma,translation) VALUES(?,?,?)',(new_id,word,t))
                    changes+=1
                elif row['translation']!=t or row['translation_source']!='Lingoy original editorial':
                    db.execute('UPDATE entries SET translation=?,translation_source=? WHERE id=?',(t,'Lingoy original editorial',row['id']));db.execute('UPDATE search SET translation=? WHERE docid=?',(t,row['id']));changes+=1
            db.execute('DELETE FROM search')
            db.execute('INSERT INTO search(docid,lemma,translation) SELECT id,lemma,translation FROM entries')
            counts={'entries':db.execute('SELECT count(*) FROM entries').fetchone()[0],'translated_entries':db.execute("SELECT count(*) FROM entries WHERE translation<>''").fetchone()[0],'ai_enriched_entries':db.execute("SELECT count(*) FROM entries WHERE translation_source='Lingoy AI definition-aligned editorial'").fetchone()[0]}
            for k,v in counts.items():db.execute('INSERT OR REPLACE INTO metadata VALUES(?,?)',(k,str(v)))
        db.execute('VACUUM')
        coverage=json.loads((ROOT/'mobile/assets/coverage.json').read_text());coverage.update(counts)
        coverage['source_note']='WordNet headwords and definitions; Uzbek meanings include original editorial and AI definition-aligned enrichment. AI text is not all human-verified. Unassigned CEFR levels remain unassigned.'
        (ROOT/'mobile/assets/coverage.json').write_text(json.dumps(coverage,ensure_ascii=False,indent=2)+'\n')
    after=list(db.execute('SELECT id,normalized,translation,translation_source FROM entries'))
    assert available.issubset({r['id'] for r in after})
    assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
    assert not db.execute('PRAGMA foreign_key_check').fetchone()
    def signature(query):
        h=hashlib.sha256()
        for row in db.execute(query):h.update((json.dumps(tuple(row),ensure_ascii=False,separators=(',',':'))+'\n').encode())
        return h.hexdigest()
    baseline=json.loads((ROOT/'data/dictionary_baseline_3_2_0.json').read_text())
    assert signature('select id,normalized from entries where id<1000000000 order by id')==baseline['identity']
    assert signature('select id,pos,words,definition,examples,antonyms from senses order by id')==baseline['senses']
    assert signature('select entry_id,sense_id,ordinal from entry_senses order by entry_id,ordinal')==baseline['relationships']
    fts_mismatches=db.execute('SELECT count(*) FROM entries e LEFT JOIN search s ON s.docid=e.id WHERE e.translation<>s.translation OR e.lemma<>s.lemma OR s.docid IS NULL').fetchone()[0]
    if apply:assert fts_mismatches==0
    report={'common_polysemy_ai_rechecks':common_rechecks,'entries_with_preserved_curated_glosses':preserved_glosses,'anatomy_slang_ai_rechecks':register_rechecks,'fts_mismatches':fts_mismatches,'original_entries_verified':baseline['entries'],'unresolved_headword_echoes':len(echoes),'entries_scanned' :len(before),'entries_after':len(after),'release_baseline_untranslated':117190,'untranslated_before_this_run':len(missing),'accepted_ai_cache':len(enriched),'schema_valid_ai_updates':len(accepted),'changed_this_run':changes,'newly_translated_this_run':sum(i in missing for i in accepted),'remaining_untranslated':sum(not r['translation'] for r in after),'ai_generated_not_human_verified':True,'ids_and_relationships_preserved':True,'dictionary_sha256':hashlib.sha256((ROOT/'mobile/assets/dictionary.db').read_bytes()).hexdigest()}
    report['newly_translated_since_3_2_0']=117190-report['remaining_untranslated']
    if apply:
        (ROOT/'mobile/assets/dictionary_revision.json').write_text(json.dumps({'version':release_version,'sha256':report['dictionary_sha256']})+'\n')
    (ROOT/f'docs/DICTIONARY_AUDIT_{release_tag}.json').write_text(json.dumps(report,indent=2)+'\n')
    with (ROOT/'data/dictionary_remaining.csv').open('w') as f:
        out=csv.writer(f);out.writerow(['id','word','status'])
        out.writerows((r['id'],r['normalized'],'untranslated') for r in after if not r['translation'])
    signals={'informal':r'\b(?:slang|informal|colloquial)\b','offensive_or_vulgar':r'\b(?:vulgar|obscene|offensive|derogatory|taboo)\b','medical_or_anatomical':r'\b(?:medical|anatomy|anatomical|disease|syndrome|infection|cell|sexual|reproductive)\b'}
    category_rows=[]
    for row in db.execute("SELECT e.id,e.normalized,e.translation,group_concat(s.definition,' ') definitions FROM entries e JOIN entry_senses es ON es.entry_id=e.id JOIN senses s ON s.id=es.sense_id GROUP BY e.id"):
        tags=[tag for tag,pattern in signals.items() if re.search(pattern,row['definitions'],re.I)]
        if tags:category_rows.append((row['id'],row['normalized'],';'.join(tags),row['translation']))
    categories={tag:{'entries':sum(tag in row[2].split(';') for row in category_rows),'untranslated':sum(tag in row[2].split(';') and not row[3] for row in category_rows)} for tag in signals}
    (ROOT/f'docs/DICTIONARY_CATEGORIES_{release_tag}.json').write_text(json.dumps({'method':'English definition keyword signals across every sense; not a label for every use of a polysemous headword','categories':categories},indent=2)+'\n')
    with (ROOT/'data/dictionary_register_audit.csv').open('w') as f:
        out=csv.writer(f);out.writerow(['id','word','definition_keyword_signals','translation']);out.writerows(category_rows)
    print(json.dumps(report,indent=2));db.close()
if __name__=='__main__':
    import sys
    audit('--apply' in sys.argv)
