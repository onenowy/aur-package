import { app } from "electron/main";
import * as path from "node:path";
import * as fs from "node:fs";

const name = "code";
const appPath = "/opt/visual-studio-code/resources/app";

// Change command name.
try {
  const fd = fs.openSync("/proc/self/comm", fs.constants.O_WRONLY);
  fs.writeSync(fd, name);
  fs.closeSync(fd);
} catch (e) {}

// Remove extra prefix arguments (electron and cli.js)
// We keep code-launcher.js as argv[0] to match Arch Linux packaging standards
const launcherIndex = process.argv.findIndex((arg) => arg.endsWith("/code-launcher.js"));
if (launcherIndex !== -1) {
  process.argv.splice(0, launcherIndex);
}

// Set application paths.
const packageJson = JSON.parse(fs.readFileSync(path.join(appPath, "package.json")));
app.setAppPath(appPath);
app.setDesktopName("code.desktop");
app.setName(name);

// Set data and cache paths to match official Microsoft binary expectations
app.setPath("userCache", path.join(app.getPath("cache"), "Code"));
app.setPath("userData", path.join(app.getPath("appData"), "Code"));
app.setVersion(packageJson.version);

// Run the application main entry point
await import(path.join(appPath, "out/main.js"));
