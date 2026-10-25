import { accessSync, constants, lstatSync, readFileSync } from 'node:fs';
import { mkdir, mkdtemp, open, link, unlink, rmdir, copyFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { delimiter, dirname, isAbsolute, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { inspectConfiguration, safeConfigText } from './config-policy.mjs';

export const PACKAGE_NAME = 'dsh-touchbar-pc2005';
const BRIDGE_DIR = dirname(fileURLToPath(import.meta.url));
const METADATA = ['package.json', 'pnpm-lock.yaml', 'pnpm-workspace.yaml', 'cordis.yml', 'cordis.yaml'];
export function parseArguments(args) {
  const options = { apply: false, profile: 'desktop' };
  const valued = new Map([['--dsh-cli', 'cli'], ['--profile', 'profile'], ['--dsh-home', 'dshHome'], ['--backup-dir', 'backupDir'], ['--write-example', 'example']]);
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--apply') options.apply = true;
    else if (arg === '--dry-run') options.dryRun = true;
    else if (arg === '--help' || arg === '-h') options.help = true;
    else if (valued.has(arg)) {
      if (!args[i + 1] || args[i + 1].startsWith('--')) throw new Error('Missing option value. Use --help.');
      options[valued.get(arg)] = args[++i];
    } else throw new Error('Unknown option. Use --help.');
  }
  if (options.apply && options.dryRun) throw new Error('Choose --apply or --dry-run, not both.');
  if (options.example && options.apply) throw new Error('--write-example only writes a new example; do not combine with --apply.');
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/.test(options.profile) || options.profile === '.' || options.profile === '..') throw new Error('Invalid profile name.');
  options.dshHome = resolve(options.dshHome || process.env.DSH_HOME || join(homedir(), '.dsh'));
  return options;
}
function executable(path) { try { accessSync(path, constants.X_OK); return lstatSync(path).isFile() || lstatSync(path).isSymbolicLink(); } catch { return false; } }
export function discoverCli(explicit) {
  if (explicit) { const path = resolve(explicit); if (!executable(path)) throw new Error('The selected DSH CLI is not executable.'); return path; }
  const desktop = '/Applications/DeepSeek Harness.app/Contents/Resources/runtime/cli/bin/dsh';
  if (executable(desktop)) return desktop;
  for (const entry of (process.env.PATH || '').split(delimiter)) {
    if (!entry) continue;
    const candidate = join(entry, 'dsh'); if (executable(candidate)) return candidate;
  }
  return null;
}
function profileConflict(options) {
  const path = join(options.dshHome, 'profiles', options.profile, 'package.json');
  let stat;
  try { stat = lstatSync(path); } catch (error) { if (error.code === 'ENOENT') return false; throw error; }
  if (!stat.isFile() || stat.isSymbolicLink() || stat.size > 2 * 1024 * 1024) throw new Error('Profile package metadata cannot be safely checked.');
  let manifest; try { manifest = JSON.parse(readFileSync(path, 'utf8')); } catch { throw new Error('Profile package metadata is invalid; nothing was changed.'); }
  const bundles = manifest?.dsh?.profile?.bundles;
  return !!manifest?.dependencies?.['dsh-pet'] || (Array.isArray(bundles) && bundles.some(item => item === 'dsh-pet' || item?.name === 'dsh-pet'));
}
export async function createExclusiveFile(path, text) {
  const directory = dirname(path);
  await mkdir(directory, { recursive: true, mode: 0o700 });
  const temporary = await mkdtemp(join(directory, '.touchbar-setup-'));
  const staged = join(temporary, 'config.json');
  try {
    const handle = await open(staged, 'wx', 0o600);
    try { await handle.writeFile(text); await handle.sync(); } finally { await handle.close(); }
    await link(staged, path); // Fails if any destination, including a symlink, already exists.
  } finally {
    await unlink(staged).catch(() => {}); await rmdir(temporary).catch(() => {});
  }
}
async function backupMetadata(options) {
  const profile = join(options.dshHome, 'profiles', options.profile);
  const records = [];
  for (const name of METADATA) {
    const path = join(profile, name);
    try { const stat = lstatSync(path); if (stat.isFile() && !stat.isSymbolicLink()) records.push({ name, path }); }
    catch (error) { if (error.code !== 'ENOENT') throw error; }
  }
  if (!records.length) return;
  const directory = options.backupDir ? resolve(options.backupDir) : join(options.dshHome, 'touchbar-setup-backups', new Date().toISOString().replace(/[:.]/g, '-') + '-' + process.pid);
  await mkdir(dirname(directory), { recursive: true, mode: 0o700 });
  await mkdir(directory, { mode: 0o700 });
  for (const { name, path } of records) await copyFile(path, join(directory, name), constants.COPYFILE_EXCL);
}
export async function runSetup(options, report = console.log) {
  if (options.example) {
    await createExclusiveFile(resolve(options.example), safeConfigText());
    report('A new safe configuration example was written. No DSH command was run.'); return;
  }
  const cli = discoverCli(options.cli);
  const inspection = inspectConfiguration(options.dshHome);
  if (!inspection.safe && !inspection.mayCreate) throw new Error('Installation stopped: existing pet configuration needs review (' + inspection.reason + '). No configuration was overwritten. Use --write-example to create a separate safe example.');
  if (profileConflict(options)) throw new Error('Installation stopped: the original dsh-pet bundle is present in this profile. Remove or disable it in DSH before installing the host-only bridge.');
  if (!options.apply) {
    report('Preview only: install the host-only bridge into the selected profile; ' + (inspection.safe ? 'keep the existing safe pet configuration unchanged.' : 'create a new private safe pet configuration.'));
    report(cli ? 'Official DSH CLI found. Use --apply to install, then reopen DSH normally.' : 'No DSH CLI found. Install DSH or provide --dsh-cli before using --apply.'); return;
  }
  if (!cli) throw new Error('No DSH CLI found. Provide --dsh-cli. Nothing was written.');
  await backupMetadata(options);
  let created = false;
  if (inspection.mayCreate) { await createExclusiveFile(inspection.file, safeConfigText()); created = true; }
  // Re-check immediately before executing the official installer. A concurrent edit
  // or newly-added pet pack must not turn a safe install into automatic model use.
  const recheck = inspectConfiguration(options.dshHome);
  if (!recheck.safe) throw new Error('Configuration changed during setup. Installation was stopped.');
  const result = spawnSync(cli, ['plugin', '--profile', options.profile, 'add', 'file:' + BRIDGE_DIR], {
    env: { ...process.env, DSH_HOME: options.dshHome }, encoding: 'utf8', maxBuffer: 2 * 1024 * 1024,
  });
  if (result.error || result.status !== 0) {
    if (created) {
      try { if (readFileSync(inspection.file, 'utf8') === safeConfigText()) await unlink(inspection.file); } catch {}
    }
    throw new Error('The official DSH installer did not complete. Its output is not echoed to protect local information. Review the DSH plugin manager; profile metadata backups were retained.');
  }
  report('Host-only bridge installed. Automatic model calls, desktop helper, balance polling and system notifications are disabled by the safe configuration.');
  report('Reopen DSH normally when its current tasks are finished. No credentials were read and DSH was not restarted.');
}
export async function runRemove(options, report = console.log) {
  const cli = discoverCli(options.cli);
  if (!options.apply) { report('Preview only: remove the bridge package through the official DSH CLI; preserve all DSH configuration, pet data, accounts and runtime files.'); return; }
  if (!cli) throw new Error('No DSH CLI found. Provide --dsh-cli.');
  await backupMetadata(options);
  const result = spawnSync(cli, ['plugin', '--profile', options.profile, 'remove', PACKAGE_NAME], { env: { ...process.env, DSH_HOME: options.dshHome }, encoding: 'utf8', maxBuffer: 2 * 1024 * 1024 });
  if (result.error || result.status !== 0) throw new Error('The official DSH uninstaller did not complete. Its output is not echoed; existing DSH data was not deleted.');
  report('Bridge package removed. Reopen DSH when idle. Configuration, chat memory, accounts and other plugins were preserved.');
}
export function usage(remove = false) {
  return `Usage: node scripts/${remove ? 'remove' : 'setup'}-dsh.mjs [--dry-run | --apply]\n  --dsh-cli PATH     Official DSH executable (auto-detected when omitted)\n  --profile NAME     DSH profile (default: desktop)\n  --dsh-home PATH    Data root (default: DSH_HOME or ~/.dsh)\n  --backup-dir PATH Optional new directory for profile metadata backups\n${remove ? '' : '  --write-example PATH  Write one new safe example, without installing\n'}Default is preview only. No shell is used and CLI output is not echoed.`;
}
