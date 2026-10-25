#!/usr/bin/env node
import { parseArguments, runRemove, usage } from '../Support/Bridge/setup-core.mjs';
try {
  const options = parseArguments(process.argv.slice(2));
  if (options.example) throw new Error('--write-example is supported only by setup-dsh.');
  if (options.help) console.log(usage(true));
  else await runRemove(options);
} catch (error) { console.error(error.message); process.exitCode = 1; }
