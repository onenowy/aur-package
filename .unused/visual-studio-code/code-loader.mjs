import { app } from 'electron';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const name = 'Code';
const appPath = '/opt/visual-studio-code/resources/app';
const packageJson = JSON.parse(readFileSync(join(appPath, 'package.json'), 'utf8'));

// 1. Remove the loader script from arguments
const loaderIndex = process.argv.findIndex(arg => arg.endsWith('code-loader.mjs'));
if (loaderIndex !== -1) {
    process.argv.splice(loaderIndex, 1);
}

// 2. Initialize the environment
app.setAppPath(appPath);
app.setName(name);
app.setDesktopName('code.desktop');

// 3. Set profile and cache paths
app.setPath('userCache', join(app.getPath('cache'), name));
app.setPath('userData', join(app.getPath('appData'), name));
app.setVersion(packageJson.version);

// 4. Hand over to the official main entry point
await import(join(appPath, 'out/main.js'));
