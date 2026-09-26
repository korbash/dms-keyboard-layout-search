const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');

function ipc(method, ...args) {
    return JSON.parse(execFileSync('dms', ['ipc', 'call', 'keyboard-layout-search', method, ...args], { encoding: 'utf8' }));
}

let shellDir;
for (const pid of fs.readdirSync('/proc').filter(name => /^\d+$/.test(name))) {
    try {
        const args = fs.readFileSync(`/proc/${pid}/cmdline`, 'utf8').split('\0');
        if (!['qs', 'quickshell'].includes(path.basename(args[0]))) continue;
        const index = args.indexOf('-p');
        if (index < 0) continue;
        const dir = args[index + 1];
        if (fs.existsSync(path.join(dir, 'Services/AppSearchService.qml'))) shellDir = dir;
    } catch (_) { /* Processes may exit while scanning. */ }
}
assert(shellDir, 'Running DMS QML directory not found');
const scorer = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(shellDir, 'Modals/DankLauncherV2/Scorer.js'), 'utf8').replace('.pragma library', ''), scorer);

assert(ipc('status').indexedApps > 0);
for (const [english, russian, prefix, expected] of [
    ['firefox', 'ашкуащч', 'ашк', 'Firefox'],
    ['telegram', 'еудупкфь', 'еуд', 'Telegram'],
    ['zed', 'яув', 'яу', 'Zed'],
    ['files', 'ашдуы', 'ашду', 'Files']
]) {
    const normal = ipc('search', english).find(app => app.name === expected);
    assert(normal, `${expected} must be installed for this local smoke test`);
    for (const query of [russian, prefix]) {
        const apps = ipc('search', query);
        assert(apps.some(app => app.id === normal.id), `${query}: original application ID preserved`);
        const items = apps.map(app => ({ ...app, type: 'app', data: app }));
        assert(scorer.scoreItems(items, query, () => null).some(result => result.item.id === normal.id), `${query}: survives DMS launcher scoring`);
        console.log(`${query} => ${expected}: OK`);
    }
}
