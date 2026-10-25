import { lstatSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

export const CONFIG_LIMIT = 256 * 1024;
export function safeConfig() {
  return {
    notificationsEnabled: false,
    whisperImageEnabled: false,
    chatImageEnabled: false,
    pets: [{ id: 'main', name: '鲸鱼娘', size: 160, display: 'web',
      whisperEnabled: false, balanceEnabled: false, workStatusEnabled: true,
      fixedEnabled: true, position: { corner: 'top-right', marginX: 24, marginY: 24 } }],
  };
}
export function safeConfigText() { return JSON.stringify(safeConfig(), null, 2) + '\n'; }

// JSONC without eval: comments are removed only outside quoted strings.
export function parseJsonc(text) {
  let out = '', quoted = false, escaped = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i], n = text[i + 1];
    if (quoted) {
      out += c;
      if (escaped) escaped = false;
      else if (c === '\\') escaped = true;
      else if (c === '"') quoted = false;
    } else if (c === '"') { quoted = true; out += c; }
    else if (c === '/' && n === '/') {
      while (i < text.length && text[i] !== '\n') i++;
      out += '\n';
    } else if (c === '/' && n === '*') {
      i += 2;
      while (i < text.length && !(text[i] === '*' && text[i + 1] === '/')) i++;
      if (i >= text.length) throw new Error('invalid-jsonc');
      i++; out += ' ';
    } else out += c;
  }
  // Drop trailing commas outside strings as permitted by JSONC.
  let clean = ''; quoted = false; escaped = false;
  for (let i = 0; i < out.length; i++) {
    const c = out[i];
    if (quoted) {
      clean += c;
      if (escaped) escaped = false;
      else if (c === '\\') escaped = true;
      else if (c === '"') quoted = false;
    } else if (c === '"') { quoted = true; clean += c; }
    else if (c === ',') {
      let j = i + 1; while (/\s/.test(out[j] ?? '') && j < out.length) j++;
      if (out[j] !== '}' && out[j] !== ']') clean += c;
    } else clean += c;
  }
  return JSON.parse(clean);
}
function statOrNull(path) {
  try { return lstatSync(path); } catch (error) { if (error.code === 'ENOENT') return null; throw error; }
}
export function inspectConfiguration(dshHome) {
  const directory = join(dshHome, 'dsh-pet');
  const file = join(directory, 'main-config.jsonc');
  const legacy = join(directory, 'main-config.json');
  const packs = join(directory, 'pet');
  const packStat = statOrNull(packs);
  if (packStat && (!packStat.isDirectory() || packStat.isSymbolicLink())) return { safe: false, reason: 'custom-pet-directory', file };
  if (packStat && readdirSync(packs).some(name => /-config\.jsonc?$/i.test(name))) return { safe: false, reason: 'custom-pet-packs', file };
  const stat = statOrNull(file);
  if (!stat) {
    if (statOrNull(legacy)) return { safe: false, reason: 'legacy-config', file };
    return { safe: false, reason: 'missing-config', file, mayCreate: true };
  }
  if (stat.isSymbolicLink() || !stat.isFile() || stat.size > CONFIG_LIMIT) return { safe: false, reason: 'unsupported-config-file', file };
  let config;
  try { config = parseJsonc(readFileSync(file, 'utf8')); }
  catch { return { safe: false, reason: 'invalid-config', file }; }
  const pet = Array.isArray(config?.pets) && config.pets.length === 1 ? config.pets[0] : null;
  const safe = config?.notificationsEnabled === false && pet?.id === 'main' && pet?.display === 'web'
    && pet?.whisperEnabled === false && pet?.balanceEnabled === false && pet?.workStatusEnabled === true;
  return { safe, reason: safe ? 'ready' : 'unsafe-settings', file };
}
export function assertSafeConfiguration(dshHome) {
  const result = inspectConfiguration(dshHome);
  if (!result.safe) throw new Error('Touch Bar bridge is disabled: run the project setup-dsh script and review the safe configuration first (' + result.reason + '). Existing files were not changed.');
  return result;
}
