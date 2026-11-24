import test from 'node:test';
import assert from 'node:assert/strict';
import {voiceSearch} from '../src/voice.js';
let recognizer;
class Recognition { constructor(){recognizer=this;} start(){} abort(){this.onend?.();} }
test('Voice uses the selected EN/UZ language and returns a trimmed result',async()=>{
  for(const [reverse,lang] of [[false,'en-US'],[true,'uz-UZ']]) {
    const session=voiceSearch(reverse,{SpeechRecognition:Recognition});
    assert.equal(recognizer.lang,lang);
    recognizer.onresult({results:[[{transcript:'  fresh start  '}]]});
    assert.equal(await session.result,'fresh start');
  }
});
test('Cancellation and no speech do not alter a query',async()=>{
  const session=voiceSearch(false,{webkitSpeechRecognition:Recognition});
  session.cancel(); assert.equal(await session.result,null);
  const second=voiceSearch(false,{SpeechRecognition:Recognition});
  recognizer.onerror({error:'no-speech'});assert.equal(await second.result,null);
});
test('Denied and unsupported microphones have readable fallback messages',async()=>{
  assert.throws(()=>voiceSearch(false,{}),/Matn bilan/);
  const session=voiceSearch(false,{SpeechRecognition:Recognition});
  recognizer.onerror({error:'not-allowed'});
  await assert.rejects(session.result,/mikrofon ruxsatini/);
});
