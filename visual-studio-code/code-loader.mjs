import { app } from 'electron';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const name = 'Code';
const appPath = '/opt/visual-studio-code/resources/app';
const packageJson = JSON.parse(readFileSync(join(appPath, 'package.json'), 'utf8'));

// 1. Arch Style: Patch process.argv to remove the loader script
const loaderIndex = process.argv.findIndex(arg => arg.endsWith('code-loader.mjs'));
if (loaderIndex !== -1) {
    process.argv.splice(loaderIndex, 1);
}

// 2. Arch Style: Initialize the environment
app.setAppPath(appPath);
app.setName(name);
app.setDesktopName('code.desktop');

// 3. Binary Specific: Fix the "Save as Root" helper path
// This is the only "extra" line compared to Arch, required for the Microsoft binary.
app.setPath('exe', '/usr/bin/code');

// 4. Arch Style: Set profile and cache paths
app.setPath('userCache', join(app.getPath('cache'), name));
app.setPath('userData', join(app.getPath('appData'), name));
app.setVersion(packageJson.version);

// 5. Arch Style: Hand over to the official main entry point
await import(join(appPath, 'out/main.js'));
