import test from 'node:test';
import assert from 'node:assert/strict';
import { CameraSession, cameraError } from '../src/camera.js';

function stream() {
  const tracks = [{ stopped: false, stop() { this.stopped = true; } }];
  return { tracks, getTracks: () => tracks };
}
test('camera requests video only, prefers the rear camera, and releases every track', async () => {
  const s = stream(), video = { srcObject: null, play: async () => {} };
  const camera = new CameraSession({ getUserMedia: async (options) => {
    assert.equal(options.audio, false);
    assert.equal(options.video.facingMode.ideal, 'environment');
    return s;
  } });
  assert.equal(await camera.open(video), true);
  assert.equal(video.srcObject, s);
  camera.stop();
  assert.equal(video.srcObject, null);
  assert.ok(s.tracks.every(t => t.stopped));
});
test('closing a pending permission prompt releases a late stream without opening the preview', async () => {
  let resolve;
  const s = stream(), video = { srcObject: null, play: async () => assert.fail('closed preview') };
  const camera = new CameraSession({ getUserMedia: () => new Promise(r => resolve = r) });
  const pending = camera.open(video);
  camera.stop(); resolve(s);
  assert.equal(await pending, false);
  assert.equal(video.srcObject, null);
  assert.ok(s.tracks.every(t => t.stopped));
});
test('playback failure stops the camera and does not retain the stream', async () => {
  const s = stream(), video = { srcObject: null, play: async () => { throw Error('playback failed'); } };
  const camera = new CameraSession({ getUserMedia: async () => s });
  await assert.rejects(camera.open(video), /playback failed/);
  assert.equal(video.srcObject, null);
  assert.ok(s.tracks.every(t => t.stopped));
});
test('permission, missing device and busy camera errors are understandable without exposing internals', () => {
  for (const name of ['NotAllowedError', 'NotFoundError', 'NotReadableError', 'SecurityError', 'UnknownError']) {
    const message = cameraError({ name, message: 'private driver internals' });
    assert.ok(message.length > 30);
    assert.ok(!message.includes('private'));
  }
});
test('an unready camera cannot produce or upload a frame', async () => {
  const camera = new CameraSession({});
  await assert.rejects(camera.capture(), /tayyor/);
});

test('a captured frame is bounded to 1600px and encoded locally as JPEG', async (t) => {
  const old = globalThis.document;
  t.after(() => { globalThis.document = old; });
  const canvas = { width: 0, height: 0, getContext: () => ({ drawImage() {} }), toBlob(callback, type, quality) {
    assert.equal(this.width, 1600); assert.equal(this.height, 1200);
    assert.equal(type, 'image/jpeg'); assert.equal(quality, .88);
    callback(new Blob(['fixture-frame'], { type }));
  } };
  globalThis.document = { createElement: (tag) => { assert.equal(tag, 'canvas'); return canvas; } };
  const s = stream(), camera = new CameraSession({ getUserMedia: async () => s });
  await camera.open({ videoWidth: 4032, videoHeight: 3024, play: async () => {} });
  const file = await camera.capture();
  assert.equal(file.type, 'image/jpeg');
  assert.equal(file.name, 'lingoy-surati.jpg');
  camera.stop();
});

test('closing while JPEG encoding is pending discards the frame', async (t) => {
  const old = globalThis.document;
  t.after(() => { globalThis.document = old; });
  let finish;
  globalThis.document = { createElement: () => ({ getContext: () => ({ drawImage() {} }), toBlob(callback) { finish = callback; } }) };
  const s = stream(), camera = new CameraSession({ getUserMedia: async () => s });
  await camera.open({ videoWidth: 800, videoHeight: 600, play: async () => {} });
  const result = camera.capture();
  camera.stop(); finish(new Blob(['old frame']));
  assert.equal(await result, null);
  assert.ok(s.tracks.every(t => t.stopped));
});
