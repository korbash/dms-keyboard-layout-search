.pragma library

function normalize(text) {
    return text.toLowerCase().normalize("NFC");
}

function buildMappings(layouts) {
    const mappings = [];
    const seen = new Set();
    for (const source of layouts) {
        for (const target of layouts) {
            if (source === target)
                continue;
            const map = Object.create(null);
            // Prefer unshifted positions when a character exists on multiple keys.
            for (let level = 0; level < 2; level++) {
                for (const key of Object.keys(source.keys)) {
                    const from = source.keys[key][level];
                    const to = target.keys[key] ? target.keys[key][level] : "";
                    if (!from || !to || map[from.normalize("NFC")] !== undefined)
                        continue;
                    map[from.normalize("NFC")] = to.normalize("NFC");
                }
            }
            const signature = JSON.stringify(map);
            if (!seen.has(signature)) {
                seen.add(signature);
                mappings.push({ characters: map, lengths: Array.from(new Set(Object.keys(map).map(function (key) { return Array.from(key).length; }))).sort(function (a, b) { return b - a; }) });
            }
        }
    }
    return mappings;
}

function convert(text, mapping) {
    // A key can emit several codepoints; longest matches preserve such XKB entries.
    const characters = Array.from(text.normalize("NFC"));
    const output = [];
    for (let index = 0; index < characters.length;) {
        let matched = 0;
        for (const length of mapping.lengths) {
            const key = characters.slice(index, index + length).join("");
            if (mapping.characters[key] === undefined)
                continue;
            output.push(mapping.characters[key]);
            matched = length;
            break;
        }
        if (!matched)
            output.push(characters[index]);
        index += matched || 1;
    }
    return normalize(output.join(""));
}

function keywordsFor(app, displayName, mappings) {
    const keywords = Array.from(app.keywords || []);
    const seen = new Set(keywords.map(normalize));
    const sources = new Set([displayName || "", app.name || "", app.genericName || "", app.id || ""].concat(keywords).map(normalize));

    function add(word) {
        if (!word || seen.has(word))
            return;
        seen.add(word);
        keywords.push(word);
    }

    for (const source of sources) {
        if (!source)
            continue;
        for (const mapping of mappings) {
            const alias = convert(source, mapping);
            if (alias === source)
                continue;
            add(alias);
            // DMS matches keyword prefixes; also index each word in multiword names.
            for (const word of alias.split(/[\s\-_]+/))
                add(word);
        }
    }
    return keywords;
}
