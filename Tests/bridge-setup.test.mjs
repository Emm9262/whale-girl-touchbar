import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, readFile, lstat, readdir, symlink, rm, copyFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { inspectConfiguration, safeConfig, safeConfigText, parseJsonc } from '../Support/Bridge/config-policy.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
async function fixture(t, metadata = false) {
  const root = await mkdtemp(join(tmpdir(), 'whale-bridge-test-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const home = join(root, 'dsh-data'), cli = join(root, 'fake-dsh');
  await mkdir(home);
  await writeFile(cli, '#!' + process.execPath + '\n' + `
import { appendFileSync } from 'node:fs';
import { join } from 'node:path';
appendFileSync(join(process.env.DSH_HOME, 'fake-cli-calls.jsonl'), JSON.stringify(process.argv.slice(2))+'\\n');
console.log('DO_NOT_ECHO_FAKE_CLI_PRIVATE_OUTPUT');
process.exit(Number(process.env.FAKE_DSH_EXIT || 0));
`, { mode: 0o700 });
  if (metadata) {
    const profile = join(home, 'profiles', 'desktop'); await mkdir(profile, { recursive: true });
    await writeFile(join(profile, 'package.json'), JSON.stringify({ name: 'fixture-profile', dsh: { profile: { bundles: ['other-plugin'] } } }));
  }
  return { root, home, cli, config: join(home, 'dsh-pet', 'main-config.jsonc'), calls: join(home, 'fake-cli-calls.jsonl') };
}
function run(f, args = [], remove = false, env = {}) {
  return spawnSync(process.execPath, [join(ROOT, 'scripts', remove ? 'remove-dsh.mjs' : 'setup-dsh.mjs'), '--dsh-cli', f.cli, '--dsh-home', f.home, ...args], { encoding: 'utf8', env: { ...process.env, ...env } });
}
async function writeConfig(f, value = safeConfigText()) { await mkdir(dirname(f.config), { recursive: true }); await writeFile(f.config, value); }

test('default and explicit dry-run leave the selected home untouched and never invoke CLI', async t => {
  const f = await fixture(t); const before = await readdir(f.home);
  for (const args of [[], ['--dry-run']]) {
    const result = run(f, args); assert.equal(result.status, 0, result.stderr); assert.match(result.stdout, /Preview only/);
    assert.deepEqual(await readdir(f.home), before); assert.equal(existsSync(f.calls), false);
  }
});
test('apply creates private safe configuration and invokes only the selected official CLI', async t => {
  const f = await fixture(t, true); const result = run(f, ['--apply']); assert.equal(result.status, 0, result.stderr);
  const config = JSON.parse(await readFile(f.config, 'utf8'));
  assert.equal(config.notificationsEnabled, false); assert.equal(config.pets[0].display, 'web');
  assert.equal(config.pets[0].whisperEnabled, false); assert.equal(config.pets[0].balanceEnabled, false);
  assert.equal((await lstat(f.config)).mode & 0o777, 0o600);
  const calls = (await readFile(f.calls, 'utf8')).trim().split('\n').map(line => JSON.parse(line));
  assert.equal(calls.length, 1); assert.deepEqual(calls[0].slice(0, 4), ['plugin', '--profile', 'desktop', 'add']);
  assert.equal(calls[0][4], 'file:' + join(ROOT, 'Support', 'Bridge'));
  assert.equal(result.stdout.includes('DO_NOT_ECHO_FAKE_CLI_PRIVATE_OUTPUT'), false);
  const backups = await readdir(join(f.home, 'touchbar-setup-backups')); assert.equal(backups.length, 1);
  assert.equal((await lstat(join(f.home, 'touchbar-setup-backups', backups[0]))).mode & 0o777, 0o700);
  assert.equal(inspectConfiguration(f.home).safe, true);
});
test('repeating apply preserves an existing safe JSONC file byte-for-byte', async t => {
  const f = await fixture(t); const text = '// local comment retained\n' + safeConfigText().replace('"鲸鱼娘"', '"Local companion"');
  await writeConfig(f, text); const before = await lstat(f.config);
  const result = run(f, ['--apply']); assert.equal(result.status, 0, result.stderr);
  assert.equal(await readFile(f.config, 'utf8'), text); assert.equal((await lstat(f.config)).mtimeMs, before.mtimeMs);
});
test('existing unsafe or malformed config stops before CLI and never exposes its content', async t => {
  const f = await fixture(t); const config = safeConfig(); config.pets[0].whisperEnabled = true; config.localNote = 'LOCAL_CONFIG_CANARY';
  for (const value of [JSON.stringify(config), '{ broken LOCAL_CONFIG_CANARY']) {
    await writeConfig(f, value); const result = run(f, ['--apply']); assert.notEqual(result.status, 0);
    assert.equal(await readFile(f.config, 'utf8'), value); assert.equal(existsSync(f.calls), false);
    assert.equal((result.stdout + result.stderr).includes('LOCAL_CONFIG_CANARY'), false);
  }
});
test('legacy config is preserved and does not get shadowed by a new default', async t => {
  const f = await fixture(t); await mkdir(dirname(f.config), { recursive: true });
  const legacy = join(dirname(f.config), 'main-config.json'); await writeFile(legacy, safeConfigText());
  const result = run(f, ['--apply']); assert.notEqual(result.status, 0); assert.equal(existsSync(f.config), false);
  assert.equal(await readFile(legacy, 'utf8'), safeConfigText()); assert.equal(existsSync(f.calls), false);
});
test('additional pet packs and original renderer bundle are refused without changing anything', async t => {
  const f = await fixture(t); await writeConfig(f); const packs = join(dirname(f.config), 'pet'); await mkdir(packs);
  await writeFile(join(packs, 'extra-config.json'), '{}'); assert.notEqual(run(f, ['--apply']).status, 0); assert.equal(existsSync(f.calls), false);
  await rm(join(packs, 'extra-config.json')); const profile = join(f.home, 'profiles', 'desktop'); await mkdir(profile, { recursive: true });
  await writeFile(join(profile, 'package.json'), JSON.stringify({ dsh: { profile: { bundles: ['dsh-pet'] } } }));
  const result = run(f, ['--apply']); assert.notEqual(result.status, 0); assert.match(result.stderr, /original dsh-pet bundle/); assert.equal(existsSync(f.calls), false);
});
test('failed CLI removes only the newly-created unchanged default', async t => {
  const f = await fixture(t, true); const result = run(f, ['--apply'], false, { FAKE_DSH_EXIT: '9' }); assert.notEqual(result.status, 0);
  assert.equal(existsSync(f.config), false); assert.equal(existsSync(join(f.home, 'profiles', 'desktop', 'package.json')), true);
  assert.equal((result.stdout + result.stderr).includes('DO_NOT_ECHO_FAKE_CLI_PRIVATE_OUTPUT'), false);
});
test('example writes are exclusive, including when the destination is a symlink', async t => {
  const f = await fixture(t); const example = join(f.root, 'example.json');
  let result = run(f, ['--write-example', example]); assert.equal(result.status, 0, result.stderr); assert.equal(await readFile(example, 'utf8'), safeConfigText());
  result = run(f, ['--write-example', example]); assert.notEqual(result.status, 0); assert.equal(await readFile(example, 'utf8'), safeConfigText());
  const link = join(f.root, 'example-link.json'); await symlink(example, link);
  result = run(f, ['--write-example', link]); assert.notEqual(result.status, 0); assert.equal(await readFile(example, 'utf8'), safeConfigText()); assert.equal(existsSync(f.calls), false);
});
test('remove uses the official package manager and keeps configuration and memory', async t => {
  const f = await fixture(t); await writeConfig(f); const memory = join(dirname(f.config), 'memory.json'); await writeFile(memory, 'fixture-memory');
  let result = run(f, [], true); assert.equal(result.status, 0); assert.equal(existsSync(f.calls), false);
  result = run(f, ['--apply'], true); assert.equal(result.status, 0, result.stderr);
  const call = JSON.parse((await readFile(f.calls, 'utf8')).trim()); assert.deepEqual(call, ['plugin', '--profile', 'desktop', 'remove', 'dsh-touchbar-pc2005']);
  assert.equal(await readFile(f.config, 'utf8'), safeConfigText()); assert.equal(await readFile(memory, 'utf8'), 'fixture-memory');
});
test('profile traversal and conflicting modes are rejected before side effects', async t => {
  const f = await fixture(t);
  for (const args of [['--profile', '../desktop', '--apply'], ['--apply', '--dry-run'], ['--apply', '--write-example', join(f.root, 'x.json')]]) {
    assert.notEqual(run(f, args).status, 0); assert.equal(existsSync(f.calls), false); assert.equal(existsSync(f.config), false);
  }
});
test('JSONC parsing preserves quoted URLs and handles comments and trailing commas', () => {
  assert.deepEqual(parseJsonc('{/* comment */ "url":"http://localhost/a//b", "items":[1,2,],}'), { url: 'http://localhost/a//b', items: [1, 2] });
  assert.throws(() => parseJsonc('{ /* unterminated'));
});
test('runtime bridge refuses upstream defaults before apply and uses only the public runtime directory', async t => {
  const f = await fixture(t); const bridge = join(f.root, 'bridge'); await mkdir(bridge);
  for (const file of ['index.mjs', 'config-policy.mjs']) await copyFile(join(ROOT, 'Support', 'Bridge', file), join(bridge, file));
  const pet = join(f.root, 'node_modules', 'dsh-pet'), homePaths = join(f.root, 'node_modules', '@deepseek-ai', 'dsh-home-paths');
  for (const [directory, text] of [[pet, 'export const inject=[]; export function apply(ctx){ctx.applied=(ctx.applied||0)+1;}'], [homePaths, 'export function resolveDshHome(){return process.env.DSH_HOME;}']]) {
    await mkdir(directory, { recursive: true }); await writeFile(join(directory, 'package.json'), JSON.stringify({ type: 'module', exports: './index.mjs' })); await writeFile(join(directory, 'index.mjs'), text);
  }
  const script = join(f.root, 'check.mjs');
  await writeFile(script, `import assert from 'node:assert/strict'; import {apply} from './bridge/index.mjs';\nconst ctx={effect(){}};\nif(process.env.EXPECT_SAFE==='1'){apply(ctx);assert.equal(ctx.applied,1);}else{assert.throws(()=>apply(ctx),/Touch Bar bridge is disabled/);assert.equal(ctx.applied,undefined);}`);
  let result = spawnSync(process.execPath, [script], { encoding: 'utf8', env: { ...process.env, DSH_HOME: f.home } }); assert.equal(result.status, 0, result.stderr);
  await writeConfig(f); result = spawnSync(process.execPath, [script], { encoding: 'utf8', env: { ...process.env, DSH_HOME: f.home, EXPECT_SAFE: '1' } }); assert.equal(result.status, 0, result.stderr);
  const code = await readFile(join(bridge, 'index.mjs'), 'utf8'); assert.match(code, /'WhaleGirlTouchBar'/);
});
