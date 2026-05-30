import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const VERSION_PATH = fileURLToPath(new URL('../VERSION', import.meta.url));

export const VERSION = readFileSync(VERSION_PATH, 'utf8').trim();
