import { app } from "electron/main";
import * as path from "node:path";
import * as fs from "node:fs";

const name = "visual-studio-code";
const appPath = "/opt/visual-studio-code/resources/app";

// Change command name.
try {
  const fd = fs.openSync("/proc/self/comm", fs.constants.O_WRONLY);
  fs.writeSync(fd, name);
  fs.closeSync(fd);
} catch (e) {}

// Remove all extra prefix arguments
// We look for this script's name and remove everything before it and the name itself
const launcherIndex = process.argv.findIndex((arg) => arg.endsWith("/code-launcher.js"));
if (launcherIndex !== -1) {
  process.argv.splice(0, launcherIndex + 1);
}

// Set application paths.
const packageJson = JSON.parse(fs.readFileSync(path.join(appPath, "package.json")));
app.setAppPath(appPath);
app.setDesktopName("code.desktop");
app.setName(name);

// The official Microsoft binary uses "Code" for its data directory
app.setPath("userData", path.join(app.getPath("appData"), "Code"));
app.setVersion(packageJson.version);

// Run the application.
await import(path.join(appPath, "out/main.js"));
