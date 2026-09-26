const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const { test } = require('node:test');
const aliases = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../plugin/LayoutMaps.js'), 'utf8').replace('.pragma library', ''), aliases);
const helper = path.join(__dirname, '../plugin/xkb_layouts.py');
const snapshots = new Map();
function maps(layout) {
    if (!snapshots.has(layout)) snapshots.set(layout, JSON.parse(execFileSync('python3', [helper, '--layouts', layout], {encoding: 'utf8'})));
    return aliases.buildMappings(snapshots.get(layout).layouts);
}

// Expected strings follow physical positions, independently of the conversion code.
for (const [layout, name, expected] of [
    ['ru', 'Firefox', 'ашкуащч'], ['ua', 'Firefox', 'ашкуащч'],
    ['gr', 'Firefox', 'φιρεφοχ'], ['tr', 'Firefox', 'fırefox'],
    ['ara', 'Firefox', 'بهقثبخء'], ['il', 'Firefox', 'כןרקכםס'],
    ['ir', 'Firefox', 'بهقثبخط'], ['th', 'Firefox', 'ดรพำดนป'],
    ['in', 'Firefox', 'िगीािदं'], ['de', 'Yazi', 'zayi'],
    ['fr', 'Yazi', 'yqwi'], ['us(dvorak)', 'Firefox', 'ucp.urq'],
    ['us(colemak)', 'Firefox', 'tupftyx']
]) {
    test(`XKB ${layout}: ${name} is found with ${expected}`, () => {
        assert(aliases.keywordsFor({ name, keywords: [] }, '', maps(layout)).includes(expected));
    });
}

test('bidirectional Russian matching, uppercase input and Shift punctuation', () => {
    assert(aliases.keywordsFor({name:'Калькулятор'}, '', maps('ru')).includes('rfkmrekznjh'));
    assert(aliases.keywordsFor({name:'ZED'}, '', maps('ru')).includes('яув'));
    assert.equal(aliases.convert('[];\',.`', maps('ru')[0]), 'хъжэбюё');
    assert.equal(aliases.convert('@', maps('ru')[0]), '"');
});

test('original keywords, multiword names, overrides, IDs and generic names survive', () => {
    const app = {name:'Google Chrome', genericName:'Web Browser', id:'chrome', keywords:['Internet','интернет']};
    const keywords = Array.from(aliases.keywordsFor(app, 'My Browser', maps('ru')));
    for (const keyword of ['Internet','интернет','пщщпду сркщьу','сркщьу','цуи икщцыук','ьн икщцыук','штеуктуе','bynthytn'])
        assert(keywords.includes(keyword), keyword);
    assert.deepEqual(app.keywords, ['Internet','интернет']);
    assert.equal(keywords.length, new Set(keywords.map(k => k.toLowerCase())).size);
});

test('no layouts leaves metadata unchanged; missing metadata is valid', () => {
    assert.deepEqual(Array.from(aliases.keywordsFor({name:'Firefox', keywords:['Web']}, '', [])), ['Web']);
    assert.deepEqual(Array.from(aliases.keywordsFor({}, '', maps('ru'))), []);
});

test('Unicode sequences, normalization, literal unmapped characters and dead keys', () => {
    const source={keys:{AD01:['x','X'],AD02:['ab','AB'],AD03:['é','É'],AD04:['d','D']}};
    const target={keys:{AD01:['😀','😀'],AD02:['क्ष','क्ष'],AD03:['z','Z'],AD04:['','']}};
    const mapping=aliases.buildMappings([source,target])[0];
    assert.equal(aliases.convert('xab e\u0301 d?', mapping), '😀क्ष z d?');
    assert.equal(aliases.convert('😀', aliases.buildMappings([source,target])[1]), 'x');
});
