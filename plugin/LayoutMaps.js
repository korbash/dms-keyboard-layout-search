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

function queryVariants(text, mappings) {
    const query = normalize(text || "").trim();
    if (!query)
        return [];
    const variants = new Set([query]);
    for (const mapping of mappings)
        variants.add(convert(query, mapping));
    return Array.from(variants).sort();
}
