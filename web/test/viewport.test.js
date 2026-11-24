import test from 'node:test';
import assert from 'node:assert/strict';
import {viewportMetrics} from '../src/viewport.js';
test('A visual-only keyboard lifts the dock and shrinks game choices',()=>{
  assert.deepEqual(viewportMetrics(844,{height:544,offsetTop:0,scale:1},true),{height:544,offset:300});
  assert.deepEqual(viewportMetrics(844,{height:544,offsetTop:100,scale:1},true),{height:544,offset:200});
});
test('Content resize, browser chrome, pinch zoom and blur cannot leave a false keyboard offset',()=>{
  assert.equal(viewportMetrics(544,{height:544,scale:1},true).offset,0);
  assert.equal(viewportMetrics(844,{height:790,scale:1},true).offset,0);
  assert.deepEqual(viewportMetrics(844,{height:422,scale:2},true),{height:844,offset:0});
  assert.equal(viewportMetrics(844,{height:544,scale:1},false).offset,0);
});
