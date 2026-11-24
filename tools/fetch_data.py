"""Fetch pinned-checksum public dictionary sources (not needed to use the APK)."""
import concurrent.futures,hashlib,json,pathlib,urllib.request,zipfile
root=pathlib.Path(__file__).resolve().parents[1]
manifest=json.loads((root/'data/sources.json').read_text())
(root/'data').mkdir(exist_ok=True)
def fetch(item):
 file=root/'data'/item['file']
 if not file.exists():
  with urllib.request.urlopen(item['url'],timeout=120) as response,file.open('wb') as output:
   while chunk:=response.read(1024*1024):output.write(chunk)
 digest=hashlib.sha256(file.read_bytes()).hexdigest()
 if digest!=item['sha256']:raise ValueError(f"Source changed: {file.name}. Review the new release and license before changing sources.json.")
 if item['file']=='wordnet.zip':
  with zipfile.ZipFile(file) as archive:
   for member in archive.infolist():
    target=(root/'data'/member.filename).resolve()
    if not target.is_relative_to((root/'data').resolve()):raise ValueError('Unsafe archive member')
   archive.extractall(root/'data')
 print(file.name,'verified')
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:list(pool.map(fetch,manifest))
