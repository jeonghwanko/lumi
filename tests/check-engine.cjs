'use strict';
// Engine-only regression: no browser, DOM, Canvas, Pixi, input, or rendering.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');

const html = path.resolve(process.argv[2] || path.join(__dirname, '../lumi.html'));
const output = process.argv[3] && path.resolve(process.argv[3]);
const root = path.dirname(html);
const bytes = fs.readFileSync(html);
const source = bytes.toString('utf8').match(/<script>\s*([\s\S]*?)<\/script>/)[1];
const catalog = require(path.join(root, 'cafe-catalog.js'));
const { makeModel } = require(path.join(root, 'cafe-model.js'));
const modelData = new Map();
const modelStorage = { getItem: k => modelData.get(k) ?? null, setItem: (k, v) => modelData.set(k, String(v)) };
const model = makeModel(modelStorage, catalog);
const initialCafe = JSON.stringify(model.read());
const progress = new Map();
const context = {
  window: {
    // This is a model adapter, not the cafe UI. The test flag suppresses rewards.
    catCafe: { settings: () => model.read().settings },
    __lumiTestRunning: true,
  },
  console, performance, setTimeout, clearTimeout,
  location: { hash: '' },
  matchMedia: () => ({ matches: false }),
  localStorage: { getItem: k => progress.get(k) ?? null,
    setItem: (k, v) => progress.set(k, String(v)), removeItem: k => progress.delete(k) },
};
vm.createContext(context);
vm.runInContext(fs.readFileSync(path.join(root, 'puzzle-theme.js'), 'utf8'), context, { timeout: 10000 });
vm.runInContext(source, context, { timeout: 10000 });
const game = context.window.__lumi;
function settle() {
  for (let n = 0; n < 1000; n++) {
    game.tick(40);
    const state = game.snap();
    if (['idle', 'win', 'lose'].includes(state.phase) && state.alive === 0 && state.hitStop <= 0) return state;
  }
  throw Error('Board did not settle');
}
const checks = [];
assert.equal(game.snap().theme, 'colored-cats-v4');
assert.deepEqual(Array.from(game.snap().labels), Array.from(context.window.PuzzleTileTheme.labels));
function check(name, fn) { fn(); checks.push({ name, pass: true }); }
check('eight_levels_initialize_64_cells', () => {
  for (let i = 0; i < 8; i++) { game.showLevel(i, 1); assert.equal(game.snap().filled, 64); assert.equal(game.snap().level, i + 1); }
});
check('legal_swap_spends_one_move_and_settles', () => {
  game.showLevel(0, 1); const before = game.snap(), hint = game.hint();
  assert.equal(hint.length, 2); assert.ok(game.legalAt(hint[0].r, hint[0].c, hint[1].r, hint[1].c));
  game.swap(...hint); const after = settle();
  assert.equal(after.moves, before.moves - 1); assert.equal(after.filled, 64); assert.ok(after.score > before.score);
});
check('invalid_swap_restores_board_moves_and_score', () => {
  game.showLevel(0, 3); const before = game.snap(); let pair;
  for (let r = 0; r < 8 && !pair; r++) for (let c = 0; c < 7 && !pair; c++) {
    if (!game.legalAt(r, c, r, c + 1)) pair = [{ r, c }, { r, c: c + 1 }];
  }
  assert.ok(pair); game.swap(...pair); const after = settle();
  assert.equal(after.moves, before.moves); assert.equal(after.score, before.score); assert.deepEqual(after.gems, before.gems);
});
check('clear_effect_state_diagnostics', () => assert.equal(game.testClearJuice().ok, true));
const runs = [];
check('forty_seeded_games_terminate_without_stall', () => {
  for (let level = 0; level < 8; level++) for (let seed = 1; seed <= 5; seed++) {
    const result = game.playGoalLevel(level, seed);
    assert.equal(result.stalled, false); assert.ok(['win', 'lose'].includes(result.phase));
    assert.ok(result.played >= 1 && result.played <= result.cap); runs.push(result);
  }
});
check('engine_regression_does_not_change_cafe_model', () => assert.equal(JSON.stringify(model.read()), initialCafe));
const result = { ok: true, mode: 'Node engine only; in-memory storage and explicit model adapter',
  source_html: html, source_sha256: crypto.createHash('sha256').update(bytes).digest('hex'), checks,
  runs, wins: runs.filter(x => x.win).length, losses: runs.filter(x => !x.win).length,
  limits: ['No DOM, Canvas, Pixi, visual rendering, audio, or mouse/touch tests',
    'Cafe UI/event integration is not exercised', 'Browser-only selfTest was not run'] };
if (output) { fs.mkdirSync(path.dirname(output), { recursive: true }); fs.writeFileSync(output, JSON.stringify(result, null, 2) + '\n'); }
console.log(JSON.stringify({ ...result, runs: runs.length }, null, 2));
