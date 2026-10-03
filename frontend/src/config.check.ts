/**
 * Frontend config check — CI acceptance criterion (per Aegis 2026-10-03)
 *
 * > No frontend configuration may reference a contract marked deprecated,
 * > dead, deferred, or out-of-scope.
 *
 * This script fails if any address in config.ts matches the denylist.
 * Run: npx tsx src/config.check.ts
 * Integrate into CI: add to package.json scripts or GitHub Actions.
 */

import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// ── Denylist: addresses that must NOT appear in active config ──
// Format: [address (lowercase), reason, decision reference]
const DENYLIST: Array<[string, string, string]> = [
  [
    '0xdc3fc3e840b14ce345638549d0d4617b75cd89b9',
    'DEPRECATED legacy Sepolia boundary',
    'G-5 (2026-10-02)',
  ],
  [
    '0x7e5095d10a4b71220938b816398918239981030a',
    'DEAD PrivacyEngine address (returns 0x)',
    'Deferred per Elijah (2026-10-01)',
  ],
];

// Addresses that are allowed to appear with explicit DEPRECATED/DEAD markers
// (i.e., the config documents them as deprecated rather than using them)
const MARKER_PATTERNS = [/DEPRECATED/i, /DEAD/i, /DO NOT USE/i];

function main(): void {
  const configPath = join(__dirname, 'config.ts');
  const configContent = readFileSync(configPath, 'utf-8');

  let failures = 0;

  for (const [deniedAddress, reason, ref] of DENYLIST) {
    // Find all occurrences (case-insensitive)
    const regex = new RegExp(deniedAddress, 'gi');
    const matches = configContent.match(regex);

    if (!matches) continue;

    // Check if each occurrence is properly marked as deprecated/dead
    const lines = configContent.split('\n');
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      if (!line.toLowerCase().includes(deniedAddress)) continue;

      // Look at surrounding context (current line + 2 lines before/after)
      const contextStart = Math.max(0, i - 2);
      const contextEnd = Math.min(lines.length, i + 3);
      const context = lines.slice(contextStart, contextEnd).join('\n');

      const isMarked = MARKER_PATTERNS.some((pattern) => pattern.test(context));

      if (!isMarked) {
        console.error(`FAIL: Unmarked denylisted address found at ${configPath}:${i + 1}`);
        console.error(`  Address: ${deniedAddress}`);
        console.error(`  Reason: ${reason} (${ref})`);
        console.error(`  Line: ${line.trim()}`);
        console.error(`  Fix: Mark as DEPRECATED/DEAD or remove from config.`);
        failures++;
      } else {
        console.log(`OK: Denylisted address properly marked at line ${i + 1} (${reason})`);
      }
    }
  }

  // Also check that no deprecated ABI files are importable from src/
  // (they should be in src/abi/deprecated/ with .DEAD extension)
  const abiDir = join(__dirname, 'abi');
  try {
    const { readdirSync } = require('fs');
    const abiFiles = readdirSync(abiDir);
    const badAbis = abiFiles.filter(
      (f: string) => f.toLowerCase().includes('privacyengine') && !f.endsWith('.DEAD')
    );
    for (const badAbi of badAbis) {
      console.error(`FAIL: PrivacyEngine ABI not quarantined: src/abi/${badAbi}`);
      console.error(`  Move to src/abi/deprecated/ with .DEAD extension.`);
      failures++;
    }
  } catch {
    // abi dir might not exist in all contexts; skip
  }

  if (failures > 0) {
    console.error(`\n${failures} check(s) failed.`);
    process.exit(1);
  }

  console.log('\nAll config checks passed.');
}

main();
