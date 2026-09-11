// Run with the installed Node runtime: node tests/web_loader.mjs
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const shell = readFileSync(new URL('../web/shell.html', import.meta.url), 'utf8');
const script = shell.match(/<script>\n([\s\S]*?)<\/script>/)[1]
  .replace('$GODOT_CONFIG', '{}').replace('$GODOT_THREADS_ENABLED', 'false');

for (const mode of ['success', 'rejection', 'unhandled', 'sync', 'missing-script', 'missing-webgl']) {
  const listeners = new Map();
  const elements = new Map();
  let options, resolve, reject, reloaded = false;
  const document = {
    addEventListener() {},
    getElementById(id) {
      if (!elements.has(id)) elements.set(id, {
        hidden: ['failure', 'retry'].includes(id), textContent: '',
        addEventListener(type, callback) { this[type] = callback; },
        removeAttribute(name) { delete this[name]; }, focus() { this.focused = true; },
      });
      return elements.get(id);
    },
  };
  class Engine {
    static getMissingFeatures() { return mode === 'missing-webgl' ? ['WebGL2'] : []; }
    constructor() { if (mode === 'sync') throw new Error('constructor failed'); }
    startGame(value) {
      options = value;
      return new Promise((yes, no) => { resolve = yes; reject = no; });
    }
  }
  const context = {
    document, console: {error() {}}, matchMedia: () => ({matches: false}), navigator: {maxTouchPoints: 0},
    location: {reload() { reloaded = true; }},
    addEventListener(type, callback) { listeners.set(type, callback); },
    removeEventListener(type, callback) { if (listeners.get(type) === callback) listeners.delete(type); },
  };
  context.window = context;
  if (mode !== 'missing-script') context.Engine = Engine;
  vm.runInNewContext(script, context);
  if (options) {
    options.onProgress(99, 100);
    assert.equal(elements.get('status').textContent, 'Yükleniyor · %99');
    options.onProgress(100, 100);
    assert.equal(elements.get('status').textContent, 'Oyun açılıyor…');
    assert.equal(elements.get('loading').hidden, false);
    if (mode === 'unhandled') {
      listeners.get('unhandledrejection')({reason: new WebAssembly.LinkError('mismatched engine')});
      options.onProgress(100, 100);
      resolve(); // A late completion must not erase a reported startup failure.
    } else if (mode === 'rejection') reject(new Error('download failed'));
    else resolve();
    await Promise.resolve();
  }
  assert.equal(elements.get('loading').hidden, mode === 'success', mode);
  assert.equal(elements.get('retry').hidden, mode === 'success', mode);
  assert.equal(listeners.has('error'), false, mode);
  assert.equal(listeners.has('unhandledrejection'), false, mode);
  if (mode !== 'success') {
    assert.equal(elements.get('status').textContent, 'Oyun açılamadı.');
    assert.equal(elements.get('failure').hidden, false);
    elements.get('retry').click();
    assert.equal(reloaded, true);
  }
}
console.log('Web loader: six startup, failure and retry scenarios passed.');
