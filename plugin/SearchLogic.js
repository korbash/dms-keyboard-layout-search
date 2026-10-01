.pragma library

function normalized(text) {
    return String(text || "").toLowerCase().normalize("NFC");
}

function distance(a, b) {
    let row = Array.from({length: b.length + 1}, (_, i) => i);
    for (let i = 0; i < a.length; i++) {
        const next = [i + 1];
        for (let j = 0; j < b.length; j++)
            next.push(Math.min(next[j] + 1, row[j + 1] + 1, row[j] + (a[i] === b[j] ? 0 : 1)));
        row = next;
    }
    return row[b.length];
}

function textScore(text, query) {
    const value = normalized(text);
    const q = normalized(query);
    if (!value || !q)
        return 0;
    if (value === q)
        return 10000;
    if (value.startsWith(q))
        return 5000;
    const words = value.split(/[\s\-_]+/);
    const queryWords = q.split(/[\s\-_]+/);
    for (let i = 0; i <= words.length - queryWords.length; i++) {
        if (queryWords.every((word, j) => words[i + j].startsWith(word)))
            return 3000;
    }
    if (value.includes(q))
        return 500;
    if (q.length < 3)
        return 0;
    const maxDistance = q.length === 3 ? 1 : q.length <= 6 ? 2 : 3;
    let best = 0;
    for (const word of [value].concat(words)) {
        if (Math.abs(word.length - q.length) > maxDistance)
            continue;
        const d = distance(word, q);
        if (d <= maxDistance)
            best = Math.max(best, 100 * (1 - d / Math.max(word.length, q.length)));
    }
    return best;
}

function matchScore(item, variants) {
    let best = 0;
    for (const query of variants) {
        let score = textScore(item.name, query);
        if (!score)
            score = textScore(item.comment, query) * 0.5;
        if (!score) {
            for (const keyword of item.keywords || [])
                score = Math.max(score, textScore(keyword, query) * 0.3);
        }
        if (!score && normalized(item.genericName).includes(query))
            score = 400;
        if (!score && normalized(item.id).includes(query))
            score = 350;
        best = Math.max(best, score);
    }
    return best;
}

function appKey(app) {
    if (app.isAction)
        return JSON.stringify(["action", app.parentApp.id, app.actionData.name, app.actionData.command || app.actionData.execString || ""]);
    return app.id || app.execString || app.exec || app.name;
}

function sourcePriorities(sources, order) {
    const result = {apps: 2, dms_settings_search: 2.35, dms_clipboard_search: 2.45, __files: 4, __folders: 4.1};
    const positions = new Map(order.map((id, index) => [id, index]));
    let next = 2.6 + order.length * 0.01;
    for (const source of sources) {
        if (positions.has(source.id))
            result[source.id] = 2.6 + positions.get(source.id) * 0.01;
        else if (source.defaultSectionPriority !== undefined)
            result[source.id] = source.defaultSectionPriority;
        else if (result[source.id] === undefined) {
            result[source.id] = next;
            next += 0.01;
        }
    }
    return result;
}

function mergeAndSort(candidates, priorities) {
    const unique = new Map();
    for (const item of candidates) {
        const key = JSON.stringify([item.sourceId, item.id]);
        const old = unique.get(key);
        if (!old || item.score > old.score)
            unique.set(key, item);
    }
    return Array.from(unique.values()).sort((a, b) => {
        const priority = (priorities[a.sourceId] ?? 5) - (priorities[b.sourceId] ?? 5);
        if (priority)
            return priority;
        if (a.sourceId !== b.sourceId)
            return a.sourceId.localeCompare(b.sourceId);
        if (a.score !== b.score)
            return b.score - a.score;
        return String(a.id).localeCompare(String(b.id));
    });
}

function launcherItems(candidates, priorities) {
    return mergeAndSort(candidates, priorities).map((item, index) => ({
        id: JSON.stringify([item.sourceId, item.id]),
        name: item.name,
        icon: String(item.icon || "").startsWith("svg+corner:") ? "material:" + String(item.icon).split("|").pop() : item.icon || "",
        comment: item.comment || "",
        action: "activate",
        payload: item,
        // The plugin-only view also scores items; preserve the complete source order there.
        _preScored: 1000000 - index
    }));
}
