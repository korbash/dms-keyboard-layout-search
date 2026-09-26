import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "plugin" as Plugin

Scope {
    id: test
    property int phase: 0
    property var baseApps: [
        { id: "firefox", name: "Firefox", keywords: ["Web"], command: ["firefox", "--new-window"], actions: [{name: "Private"}], workingDirectory: "/tmp", runInTerminal: false },
        { id: "yazi", name: "Yazi", keywords: [], command: ["yazi"], runInTerminal: true }
    ]
    property int aliasCount: 0
    property var instance: null

    QtObject {
        id: settings
        property string layouts: "us,ru,gr,de,fr,ara,il,us(dvorak)"
        signal pluginDataChanged(string changedPluginId)
        function loadPluginData(id, key, fallback) { return layouts; }
    }

    Component { id: pluginComponent; Plugin.LayoutSearchDaemon { pluginService: settings } }

    function check(condition, message) {
        if (condition)
            return;
        console.error("LAYOUT_SEARCH_FAIL:", message);
        Qt.exit(1);
        throw new Error(message);
    }

    function verify() {
        if (!instance || instance.loading)
            return;
        if (phase === 0) {
            check(instance.lastError === "", instance.lastError);
            check(instance.layoutNames.length === 8, "all configured layouts loaded");
            const firefox = AppSearchService.applications[0];
            for (const alias of ["ашкуащч", "φιρεφοχ", "بهقثبخء", "כןרקכםס", "ucp.urq"])
                check(firefox.keywords.indexOf(alias) !== -1, "alias " + alias);
            check(AppSearchService.applications[1].keywords.indexOf("zayi") !== -1, "German alias");
            check(AppSearchService.applications[1].keywords.indexOf("yqwi") !== -1, "French alias");
            for (const key of ["id", "name", "command", "actions", "workingDirectory", "runInTerminal"])
                check(JSON.stringify(firefox[key]) === JSON.stringify(baseApps[0][key]), "launch metadata: " + key);
            aliasCount = firefox.keywords.length;
            instance.refresh();
            check(AppSearchService.applications[0].keywords.length === aliasCount, "reindex has no duplicates");
            check(instance.originalApp(AppSearchService.applications[0]) === baseApps[0], "original object retained");
            SessionData.appOverrides = {firefox: {name: "Telegram"}};
            check(AppSearchService.applications[0].keywords.indexOf("еудупкфь") !== -1, "custom name updated");
            AppSearchService.applications = baseApps.concat([{id:"zed",name:"Zed",command:["zed"],keywords:[]}]);
            check(AppSearchService.applications[2].keywords.indexOf("яув") !== -1, "new applications indexed");
            const before = JSON.stringify(AppSearchService.applications[0].keywords);
            instance.acceptSnapshot('{"error":"deliberate test error"}');
            check(instance.lastError === "deliberate test error", "snapshot failure reported");
            check(JSON.stringify(AppSearchService.applications[0].keywords) === before, "snapshot failure preserves working index");
            phase = 1;
            settings.layouts = "tr";
            instance.reloadLayouts();
            settings.layouts = "us,ru";
            settings.pluginDataChanged("keyboardLayoutSearch");
            return;
        }
        if (phase === 1) {
            if (instance.pendingReload || instance.lastError || instance.layoutNames.length !== 2)
                return;
            check(instance.layoutNames[1] === "Russian", "latest settings win over running helper");
            check(AppSearchService.applications[0].keywords.indexOf("φιρεφοχ") === -1, "old maps replaced");
            phase = 2;
            instance.destroy();
            instance = null;
            finish.start();
        }
    }

    Connections {
        target: test.instance
        function onLoadingChanged() { if (!test.instance.loading) Qt.callLater(test.verify); }
    }

    Timer {
        id: finish
        interval: 0
        onTriggered: {
            check(AppSearchService.applications.length === 3, "new app preserved on disable");
            check(AppSearchService.applications[0] === baseApps[0], "original restored on disable");
            check(JSON.stringify(AppSearchService.applications[0].keywords) === '["Web"]', "original keywords restored");
            console.log("LAYOUT_SEARCH_COMPONENT_PASS");
            Qt.quit();
        }
    }

    Component.onCompleted: {
        AppSearchService.applications = baseApps;
        instance = pluginComponent.createObject(test);
    }
}
