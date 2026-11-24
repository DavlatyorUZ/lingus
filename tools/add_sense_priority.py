"""Create compact first-sense ordering from the pinned WordNet archive.

Run tools/fetch_data.py first, or provide --wordnet for a verified local archive.
The dictionary itself is never modified.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sqlite3
import zipfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--wordnet', type=Path, default=root/'data/wordnet.zip')
parser.add_argument('--dictionary', type=Path, default=root/'mobile/assets/dictionary.db')
parser.add_argument('--output', type=Path, default=root/'mobile/assets/sense_priority.json')
args = parser.parse_args()
source = next(s for s in json.loads((root/'data/sources.json').read_text()) if s['file']=='wordnet.zip')
digest = hashlib.sha256(args.wordnet.read_bytes()).hexdigest()
if digest != source['sha256']:
    raise SystemExit('WordNet checksum changed; review the source before generating assets.')
connection = sqlite3.connect(f'{args.dictionary.resolve().as_uri()}?mode=ro', uri=True)
entries = dict(connection.execute('SELECT normalized,id FROM entries'))
priority = {}
with zipfile.ZipFile(args.wordnet) as archive:
    for filename, pos in [('noun','n'),('verb','v'),('adj','a'),('adv','r')]:
        for line in archive.read('wordnet/index.'+filename).decode().splitlines():
            if not line or line.startswith(' '):
                continue
            parts = line.split()
            count, pointers = int(parts[2]), int(parts[3])
            offsets = parts[6+pointers:]
            if len(offsets) != count:
                raise ValueError('Unexpected WordNet index format')
            lemma = parts[0].replace('_',' ').lower()
            if count < 2 or lemma not in entries:
                continue
            sense = pos+str(int(offsets[0]))
            found = connection.execute('SELECT 1 FROM entry_senses WHERE entry_id=? AND sense_id=?',(entries[lemma],sense)).fetchone()
            if not found:
                raise ValueError(f'Unmatched sense: {lemma}/{pos}/{sense}')
            priority[f'{lemma}:{pos}'] = sense
connection.close()
payload = {'source':'WordNet 3.0 index files, first sense for polysemous lemmas','source_sha256':digest,'first_senses':priority}
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_text(json.dumps(payload,separators=(',',':'))+'\n')
print(f'{len(priority)} first-sense entries verified and written')
