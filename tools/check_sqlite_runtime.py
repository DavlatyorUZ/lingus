"""Check the actual bundled dictionary on a selected SQLite runtime.

Usage: python tools/check_sqlite_runtime.py /absolute/path/libsqlite3.so
SQLite 3.44.x can misreport read-only FTS4 integrity. The production path checks
a writable private handle first and enables query_only before normal lookups.
"""
from pathlib import Path
import ctypes, ctypes.util, json, sys, tempfile, shutil

root = Path(__file__).resolve().parents[1]
sql = ctypes.CDLL(sys.argv[1] if len(sys.argv)>1 else ctypes.util.find_library('sqlite3'))
sql.sqlite3_libversion.restype=ctypes.c_char_p
sql.sqlite3_open_v2.argtypes=[ctypes.c_char_p,ctypes.POINTER(ctypes.c_void_p),ctypes.c_int,ctypes.c_void_p]
sql.sqlite3_exec.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_void_p,ctypes.c_void_p,ctypes.POINTER(ctypes.c_char_p)]
sql.sqlite3_close.argtypes=[ctypes.c_void_p]
callback_type=ctypes.CFUNCTYPE(ctypes.c_int,ctypes.c_void_p,ctypes.c_int,ctypes.POINTER(ctypes.c_char_p),ctypes.POINTER(ctypes.c_char_p))
def execute(db, statement):
    rows=[]
    @callback_type
    def callback(_, count, values, names):
        rows.append([values[i].decode() if values[i] else None for i in range(count)])
        return 0
    error=ctypes.c_char_p()
    code=sql.sqlite3_exec(db,statement.encode(),callback,None,ctypes.byref(error))
    return {'code':code,'rows':rows[:3]}
with tempfile.TemporaryDirectory(prefix='lingoy-runtime-') as temp:
    target=Path(temp)/'content.db';shutil.copyfile(root/'mobile/assets/dictionary.db',target)
    results={}
    for flags,kind in [(1,'old_read_only_check'),(2,'fixed_check')]:
        db=ctypes.c_void_p();assert sql.sqlite3_open_v2(str(target).encode(),ctypes.byref(db),flags,None)==0
        results[kind]=execute(db,'PRAGMA quick_check')
        if flags==2:
            assert results[kind]['rows']==[['ok']],results
            assert execute(db,'PRAGMA query_only=ON')['code']==0
            results['lookup']=execute(db,"SELECT lemma FROM entries WHERE normalized='start'")
            assert results['lookup']['rows']==[['start']]
            results['fts_lookup']=execute(db,"SELECT e.lemma FROM search JOIN entries e ON e.id=search.docid WHERE search.lemma MATCH 'start' AND e.normalized='start'")
            assert results['fts_lookup']['rows']==[['start']]
            results['writes_blocked']=execute(db,'DELETE FROM entries')['code']!=0
            assert results['writes_blocked']
        sql.sqlite3_close(db)
    print(json.dumps({'sqlite':sql.sqlite3_libversion().decode(),**results},ensure_ascii=False,indent=2))
