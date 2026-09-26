pragma Singleton
import QtQuick
import Quickshell
Singleton {
    property var applications: []
    property var _cachedVisibleApps: null
    property var _cachedCategories: null
    property int cacheVersion: 0
    function invalidateLauncherCache() { cacheVersion++; }
    function searchApplications(query) { return []; }
}
