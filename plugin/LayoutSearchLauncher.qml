import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "SearchLogic.js" as Search

Item {
    id: root

    property var pluginService: null
    property string pluginId: "keyboardLayoutSearch"
    property string trigger: ""
    readonly property var daemon: pluginService?.pluginDaemonInstances[pluginId] || null
    property bool collecting: false
    property bool notifying: false
    property bool stopping: false
    property string asyncKey: ""
    property int generation: 0
    property int pending: 0
    property var asyncResults: []
    property var processIds: []
    readonly property bool loading: pending > 0
    signal itemsChanged()

    function notify() {
        if (stopping || collecting || notifying)
            return;
        notifying = true;
        try {
            itemsChanged();
            if (pluginService)
                pluginService.requestLauncherUpdate(pluginId);
        } finally {
            notifying = false;
        }
    }

    function invalidateAsync() {
        asyncKey = "";
        generation++;
        pending = 0;
        asyncResults = [];
        cancelProcesses();
        notify();
    }

    function cancelProcesses() {
        for (const id of processIds)
            Proc.release(id);
        processIds = [];
    }

    function sources() {
        const list = [];
        const external = pluginService ? pluginService.getLauncherPlugins() : {};
        const builtin = AppSearchService.getBuiltInLauncherPlugins();
        for (const id of Object.keys(external)) {
            if (id !== pluginId && SettingsData.getPluginAllowWithoutTrigger(id))
                list.push({id: id, builtin: false});
        }
        for (const id of Object.keys(builtin)) {
            if (SettingsData.getPluginAllowWithoutTrigger(id))
                list.push({id: id, builtin: true, defaultSectionPriority: builtin[id].defaultSectionPriority});
        }
        const order = SettingsData.launcherPluginOrder || [];
        if (order.length) {
            list.sort((a, b) => {
                const ai = order.indexOf(a.id), bi = order.indexOf(b.id);
                return (ai < 0 ? 9999 : ai) - (bi < 0 ? 9999 : bi) || a.id.localeCompare(b.id);
            });
        }
        return list;
    }

    function applicationItems(variants) {
        const results = [];
        const usage = AppUsageHistoryData.appUsageRanking || {};
        for (const app of AppSearchService.getVisibleApplications()) {
            const key = Search.appKey(app);
            const history = usage[key] || usage[String(key).replace(/\.desktop$/, "")];
            const bonus = history ? Math.min(history.usageCount * 50, 2000) : 0;
            const score = Search.matchScore(app, variants);
            if (score > 0)
                results.push({id: key, sourceId: "apps", kind: "app", name: app.name, comment: app.comment, icon: app.icon, score: score + bonus, data: app});
            if (!SessionData.searchAppActions)
                continue;
            for (const action of app.actions || []) {
                const match = {name: action.name, parentApp: app, actionData: action, isAction: true};
                const actionScore = Math.max.apply(null, variants.map(q => Search.textScore(action.name, q)));
                if (actionScore > 0)
                    results.push({id: Search.appKey(match), sourceId: "apps", kind: "action", name: action.name, comment: app.name, icon: action.icon || app.icon, score: actionScore + bonus, data: match});
            }
        }
        for (const app of AppSearchService.getCoreApps("")) {
            const score = Search.matchScore(app, variants);
            if (score > 0)
                results.push({id: "core:" + app.action, sourceId: "apps", kind: "core", name: app.name, comment: app.comment, icon: app.icon, score: score, data: app});
        }
        return results;
    }

    function getItems(query) {
        const text = String(query || "").trim();
        if (collecting || stopping)
            return [];
        if (!text) {
            asyncKey = "";
            generation++;
            pending = 0;
            asyncResults = [];
            cancelProcesses();
            return [];
        }
        collecting = true;
        try {
            const variants = daemon ? daemon.queryVariants(text) : [text.toLowerCase()];
            const providers = sources();
            const candidates = applicationItems(variants);
            for (const provider of providers) {
                if (provider.id === "dms_clipboard_search")
                    continue;
                // Third-party providers can own mutable query state; call each once with literal text.
                const queries = !provider.builtin || provider.id === "dms_qr_generator" ? [text] : variants;
                for (const q of queries) {
                    const items = provider.builtin ? AppSearchService.getBuiltInLauncherItems(provider.id, q) : AppSearchService.getPluginItemsForPlugin(provider.id, q);
                    for (let i = 0; i < items.length; i++) {
                        const item = items[i];
                        const key = JSON.stringify([item.id || item.action || item.name, provider.id === "dms_settings_search" ? item.name : ""]);
                        candidates.push({id: key, sourceId: provider.id, kind: provider.builtin ? "builtin" : "plugin", name: item.name, comment: item.comment || item.description, icon: item.icon, score: 10000 - i, data: item});
                    }
                }
            }
            requestAsync(variants, providers);
            const order = SettingsData.launcherPluginOrder || [];
            const priorities = Search.sourcePriorities(providers.concat([{id: "__files"}, {id: "__folders"}]), order);
            return Search.launcherItems(candidates.concat(asyncResults), priorities);
        } finally {
            collecting = false;
        }
    }

    function requestAsync(variants, providers) {
        const clipboard = ClipboardService.clipboardAvailable && providers.some(p => p.id === "dms_clipboard_search");
        const files = DSearchService.dsearchAvailable && SettingsData.dankLauncherV2IncludeFilesInAll;
        const folders = DSearchService.dsearchAvailable && SettingsData.dankLauncherV2IncludeFoldersInAll;
        const key = JSON.stringify([variants, clipboard, files, folders]);
        if (key === asyncKey)
            return;
        asyncKey = key;
        generation++;
        pending = 0;
        asyncResults = [];
        cancelProcesses();
        const queries = variants.filter(q => q.length >= 2);
        const jobs = [];
        for (const query of queries) {
            if (clipboard)
                jobs.push({kind: "clipboard", query: query});
            if (files)
                jobs.push({kind: "file", query: query});
            if (folders)
                jobs.push({kind: "dir", query: query});
        }
        pending = jobs.length;
        const version = generation;
        for (let i = 0; i < jobs.length; i++) {
            const job = jobs[i];
            if (job.kind === "clipboard") {
                DMSService.sendRequest("clipboard.search", {query: job.query, limit: 20}, response => {
                    if (stopping || version !== generation)
                        return;
                    const results = (response.result?.entries || []).map(entry => ({
                        id: entry.id || entry.hash,
                        sourceId: "dms_clipboard_search",
                        kind: "clipboard",
                        name: String(entry.preview || I18n.tr("Image")).replace(/\s+/g, " ").slice(0, 140),
                        comment: I18n.tr("Clipboard"),
                        icon: "material:content_paste",
                        score: (entry.pinned ? 1000000000000000 : 0) + Number(entry.id || 0),
                        data: entry
                    }));
                    finishAsync(version, results);
                });
                continue;
            }
            const id = pluginId + "-files-" + i;
            processIds.push(id);
            const args = ["dsearch", "search", job.query, "--json", "-n", "20", "--fuzzy", "--sort", "score", "--desc=true"];
            if (DSearchService.supportsTypeFilter)
                args.push("-t", job.kind);
            Proc.runCommand(id, args, (stdout, exitCode) => {
                if (stopping || version !== generation)
                    return;
                let hits = [];
                if (exitCode === 0) {
                    try { hits = JSON.parse(stdout).hits || []; }
                    catch (error) { console.warn("Keyboard Layout Search: invalid file search response"); }
                }
                const results = hits.map(hit => ({
                    id: hit.id,
                    sourceId: hit.locations?.doc_type?.dir ? "__folders" : "__files",
                    kind: "file",
                    name: String(hit.id || "").split("/").pop(),
                    comment: hit.id,
                    icon: hit.locations?.doc_type?.dir ? "material:folder" : "material:insert_drive_file",
                    score: hit.score || 0,
                    data: {path: hit.id}
                })).filter(item => item.sourceId === "__folders" ? folders : files);
                finishAsync(version, results);
            }, 100, 5000);
        }
    }

    function finishAsync(version, results) {
        if (stopping || version !== generation)
            return;
        asyncResults = asyncResults.concat(results);
        pending--;
        if (pending === 0)
            Qt.callLater(notify);
    }

    function executeItem(item) {
        const result = item?.payload;
        if (!result)
            return;
        switch (result.kind) {
        case "app":
            SessionService.launchDesktopEntry(result.data);
            AppUsageHistoryData.addAppUsage(result.data);
            break;
        case "action":
            SessionService.launchDesktopAction(result.data.parentApp, result.data.actionData);
            AppUsageHistoryData.addAppUsage(result.data.parentApp);
            break;
        case "core":
            AppSearchService.executeCoreApp(result.data);
            break;
        case "builtin":
            AppSearchService.executeBuiltInLauncherItem(result.data);
            break;
        case "plugin":
            AppSearchService.executePluginItem(result.data, result.sourceId);
            break;
        case "clipboard":
            ClipboardService.copyEntry(result.data);
            break;
        case "file":
            SessionService.openPath(result.data.path);
            break;
        }
    }

    function getPasteArgs(item) {
        const result = item?.payload;
        if (result?.kind === "plugin")
            return AppSearchService.getPluginPasteArgs(result.sourceId, result.data);
        return null;
    }

    Connections {
        target: root.daemon
        function onLayoutsChanged() { root.invalidateAsync(); }
    }
    Connections {
        target: root.pluginService
        function onRequestLauncherUpdate(id) { if (id !== root.pluginId) root.notify(); }
        function onPluginListUpdated() { root.notify(); }
    }
    Connections {
        target: AppSearchService
        function onCacheVersionChanged() { root.notify(); }
    }
    Connections {
        target: SettingsSearchService
        function onIndexLoadedChanged() { Qt.callLater(root.notify); }
    }
    Connections {
        target: SettingsData
        function onLauncherPluginOrderChanged() { root.notify(); }
        function onLauncherPluginVisibilityChanged() { root.invalidateAsync(); }
        function onBuiltInPluginSettingsChanged() { root.invalidateAsync(); }
    }
    Connections {
        target: ClipboardService
        function onHistoryCopied() { root.invalidateAsync(); }
        function onHistoryCleared() { root.invalidateAsync(); }
    }

    Component.onDestruction: {
        stopping = true;
        generation++;
        cancelProcesses();
    }
}
