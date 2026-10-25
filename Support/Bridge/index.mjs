import { apply as applyPet, inject as petInject } from 'dsh-pet';
import { resolveDshHome } from '@deepseek-ai/dsh-home-paths';
import { assertSafeConfiguration } from './config-policy.mjs';
import { mkdir, readFile, unlink, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';

// Only the host entry is loaded. There is deliberately no dsh.client entry:
// the native Touch Bar is the renderer, so no browser overlay or Electron helper
// is created. The upstream web surface is consumed by this native adapter.
export const name = 'dsh-touchbar-pc2005';
export const inject = petInject;
export function apply(ctx) {
  assertSafeConfiguration(resolveDshHome());
  applyPet(ctx);
  ctx.effect(() => {
    let disposed = false;
    let timer;
    const directory = join(homedir(), 'Library', 'Application Support', 'WhaleGirlTouchBar');
    const file = join(directory, 'pc2005-runtime.json');
    const publish = async () => {
      if (disposed) return;
      const port = ctx.webServer?.port;
      if (!Number.isInteger(port) || port < 1 || port > 65535) {
        timer = setTimeout(publish, 500); timer.unref?.(); return;
      }
      const payload = { schemaVersion: 1, provider: 'PC2005-cloud/dsh-pet', version: '0.3.8', renderer: 'native-touchbar', baseURL: `http://127.0.0.1:${port}`, processId: process.pid };
      await mkdir(directory, { recursive: true, mode: 0o700 });
      if (!disposed) await writeFile(file, JSON.stringify(payload, null, 2) + '\n', { mode: 0o600 });
    };
    void publish().catch(() => ctx.logger?.warn?.('Touch Bar endpoint could not be published'));
    return () => {
      disposed = true; clearTimeout(timer);
      void readFile(file, 'utf8').then(raw => {
        if (JSON.parse(raw).processId === process.pid) return unlink(file);
      }).catch(() => {});
    };
  }, 'touchbar: publish non-secret local endpoint');
}
