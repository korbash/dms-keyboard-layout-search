pragma Singleton
import QtQuick
import Quickshell
Singleton {
    property var appOverrides: ({})
    function getAppOverride(id) { return appOverrides[id] || null; }
}
