#!/usr/bin/env node
import { parseArguments, runSetup, usage } from '../Support/Bridge/setup-core.mjs';
try {
  const options = parseArguments(process.argv.slice(2));
  if (options.help) console.log(usage());
  else await runSetup(options);
} catch (error) { console.error(error.message); process.exitCode = 1; }
