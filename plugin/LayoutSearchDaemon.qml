import QtQuick
import Quickshell.Io
import "LayoutMaps.js" as Aliases

Item {
    id: root

    property var pluginService: null
    property string pluginId: "keyboardLayoutSearch"
    property bool stopping: false
    property bool pendingReload: false
    property bool receivedPayload: false
    property string requestedLayouts: ""
    property bool initialized: false
    property var mappings: []
    property var layoutNames: []
    property string keymapSource: ""
    property string lastError: ""
    readonly property bool loading: keymapProcess.running
    signal layoutsChanged()

    function queryVariants(query) {
        return Aliases.queryVariants(query, mappings);
    }

    function reloadLayouts() {
        if (stopping)
            return;
        if (keymapProcess.running) {
            pendingReload = true;
            return;
        }
        receivedPayload = false;
        lastError = "";
        const layouts = pluginService ? pluginService.loadPluginData(pluginId, "layouts", "") : "";
        requestedLayouts = layouts;
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
            layoutsChanged();
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
                Qt.callLater(function () {
                    root.pendingReload = false;
                    root.reloadLayouts();
                });
            }
        }
    }

    Connections {
        target: root.pluginService
        function onPluginDataChanged(changedPluginId) {
            if (root.initialized && changedPluginId === root.pluginId && root.pluginService.loadPluginData(root.pluginId, "layouts", "") !== root.requestedLayouts)
                root.reloadLayouts();
        }
    }

    Component.onCompleted: {
        if (pluginService && pluginService.loadPluginData(pluginId, "noTrigger", null) === null)
            pluginService.savePluginData(pluginId, "noTrigger", true);
        initialized = true;
        reloadLayouts();
    }
    Component.onDestruction: stopping = true

    IpcHandler {
        target: "keyboard-layout-search"

        function status(): string {
            const launcher = root.pluginService?.pluginInstances?.[root.pluginId];
            return JSON.stringify({ mode: "launcher", layouts: root.layoutNames, source: root.keymapSource, loading: root.loading, searching: launcher?.loading || false, error: root.lastError });
        }

        function refresh(): string {
            root.reloadLayouts();
            return "Keyboard layout refresh requested";
        }

        function search(query: string): string {
            const launcher = root.pluginService ? root.pluginService.ensureLauncherInstance(root.pluginId) : null;
            return JSON.stringify(launcher ? launcher.getItems(query).map(item => ({ id: item.id, name: item.name, source: item.payload.sourceId, score: item.payload.score })) : []);
        }

        function variants(query: string): string {
            return JSON.stringify(root.queryVariants(query));
        }
    }
}
