import test from 'node:test';
import assert from 'node:assert/strict';
const storage=new Map();
globalThis.window=new EventTarget();
globalThis.localStorage={getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v)};
const {state,recentViewed,rememberViewed}=await import('../src/store.js');
test('Only explicitly viewed words enter recents; refresh order and bookmarks remain independent',()=>{
  assert.deepEqual(recentViewed(),[]);
  rememberViewed({id:1,lemma:'start'});rememberViewed({id:2,lemma:'begin'});rememberViewed({id:1,lemma:'start'});
  assert.deepEqual(recentViewed().map(w=>w.id),[1,2]);assert.deepEqual(state().saved,{});
  assert.deepEqual(JSON.parse(storage.get('lingoy-state-guest')).recent.map(w=>w.id),[1,2]);
  rememberViewed({id:3,lemma:'secret'},'different-account');assert.equal(recentViewed().length,2);
  for(let id=4;id<40;id++)rememberViewed({id,lemma:'word'+id});
  assert.equal(recentViewed().length,30);assert.equal(recentViewed()[0].id,39);
});

test('A full history store cannot block opening a word',()=>{
  const setItem=localStorage.setItem;
  localStorage.setItem=()=>{throw Error('quota exceeded');};
  try { assert.equal(rememberViewed({id:100,lemma:'word'}),false); }
  finally {localStorage.setItem=setItem;}
});
