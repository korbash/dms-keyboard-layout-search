import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import "LayoutMaps.js" as Aliases

Item {
    id: root

    property var pluginService: null
    property string pluginId: "keyboardLayoutSearch"
    property bool updating: false
    property bool stopping: false
    property bool pendingReload: false
    property bool receivedPayload: false
    property int indexedApps: 0
    property var mappings: []
    property var layoutNames: []
    property string keymapSource: ""
    property string lastError: ""
    readonly property bool loading: keymapProcess.running

    function originalApp(app) {
        return app._keyboardLayoutSearchOriginal || app;
    }

    function invalidate() {
        AppSearchService._cachedVisibleApps = null;
        AppSearchService._cachedCategories = null;
        AppSearchService.invalidateLauncherCache();
    }

    function refresh() {
        if (updating || stopping)
            return;
        updating = true;
        try {
            const apps = AppSearchService.applications.map(function (entry) {
                const app = originalApp(entry);
                if (root.mappings.length === 0)
                    return app;
                const override = SessionData.getAppOverride(app.id || app.execString || app.exec || "");
                return Object.assign({}, app, {
                    keywords: Aliases.keywordsFor(app, override ? override.name : "", root.mappings),
                    _keyboardLayoutSearchOriginal: app
                });
            });
            AppSearchService.applications = apps;
            indexedApps = apps.length;
            invalidate();
        } finally {
            updating = false;
        }
    }

    function reloadLayouts() {
        if (stopping)
            return;
        if (keymapProcess.running) {
            pendingReload = true;
            return;
        }
        if (typeof AppSearchService.invalidateLauncherCache !== "function") {
            lastError = "This DMS version does not expose the required application search API";
            return;
        }
        receivedPayload = false;
        lastError = "";
        const layouts = pluginService ? pluginService.loadPluginData(pluginId, "layouts", "") : "";
        keymapProcess.command = ["python3", decodeURIComponent(Qt.resolvedUrl("xkb_layouts.py").toString().replace(/^file:\/\//, "")), "--layouts", layouts];
        keymapProcess.running = true;
    }

    function acceptSnapshot(output) {
        receivedPayload = true;
        if (stopping || pendingReload)
            return;
        try {
            const data = JSON.parse(output);
            if (data.error)
                throw new Error(data.error);
            if (data.version !== 1 || !Array.isArray(data.layouts) || data.layouts.length === 0)
                throw new Error("Invalid XKB helper response");
            const nextMappings = Aliases.buildMappings(data.layouts);
            mappings = nextMappings;
            layoutNames = data.layouts.map(function (layout) { return layout.name; });
            keymapSource = data.source;
            lastError = "";
            refresh();
        } catch (error) {
            // Keep the last usable index if a refresh fails.
            lastError = String(error.message || error);
            console.warn("Keyboard Layout Search:", lastError);
        }
    }

    Process {
        id: keymapProcess
        stdout: StdioCollector {
            onStreamFinished: root.acceptSnapshot(text)
        }
        stderr: StdioCollector {}
        onExited: exitCode => {
            if (!root.receivedPayload && exitCode !== 0)
                root.lastError = "The XKB helper could not start; check Python 3 and libxkbcommon";
            if (root.pendingReload) {
                root.pendingReload = false;
                Qt.callLater(root.reloadLayouts);
            }
        }
    }

    Connections {
        target: AppSearchService
        function onApplicationsChanged() { root.refresh(); }
    }

    Connections {
        target: SessionData
        function onAppOverridesChanged() { root.refresh(); }
    }

    Connections {
        target: root.pluginService
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId)
                root.reloadLayouts();
        }
    }

    Component.onCompleted: reloadLayouts()
    Component.onDestruction: {
        stopping = true;
        AppSearchService.applications = AppSearchService.applications.map(originalApp);
        if (typeof AppSearchService.invalidateLauncherCache === "function")
            invalidate();
    }

    IpcHandler {
        target: "keyboard-layout-search"

        function status(): string {
            return JSON.stringify({ indexedApps: root.indexedApps, layouts: root.layoutNames, source: root.keymapSource, loading: root.loading, error: root.lastError });
        }

        function refresh(): string {
            root.reloadLayouts();
            return "Keyboard layout refresh requested";
        }

        function search(query: string): string {
            return JSON.stringify(AppSearchService.searchApplications(query).map(function (app) {
                return { id: app.id, name: app.name, keywords: app.keywords };
            }));
        }
    }
}
