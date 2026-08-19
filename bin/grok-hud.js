#!/usr/bin/env node
/** grok-hud CLI entry — loads ../dist/index.js */
import { pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const entry = join(__dirname, '..', 'dist', 'index.js');
await import(pathToFileURL(entry).href);
