import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "keyboardLayoutSearch"
    readonly property var instance: PluginService.pluginDaemonInstances[pluginId] || null

    StringSetting {
        settingKey: "layouts"
        label: I18n.trFor("keyboardLayoutSearch", "Keyboard layouts")
        description: I18n.trFor("keyboardLayoutSearch", "Leave empty to read the Wayland keymap. Or enter up to eight XKB layouts and variants, separated by commas. English (US) is always included as a reference.")
        placeholder: "us,ru,de,fr,us(dvorak)"
        defaultValue: ""
    }

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        color: root.instance?.lastError ? Theme.error : Theme.surfaceVariantText
        text: {
            if (!root.instance)
                return I18n.trFor("keyboardLayoutSearch", "Enable the plugin to load keyboard layouts.");
            if (root.instance.loading)
                return I18n.trFor("keyboardLayoutSearch", "Reading keyboard layouts…");
            if (root.instance.lastError)
                return root.instance.lastError;
            return I18n.trFor("keyboardLayoutSearch", "Loaded layouts: %1").arg(root.instance.layoutNames.join(", "));
        }
    }

    DankButton {
        text: I18n.trFor("keyboardLayoutSearch", "Reload keyboard layouts")
        enabled: root.instance !== null && !root.instance.loading
        onClicked: root.instance.reloadLayouts()
    }

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.surfaceVariantText
        text: I18n.trFor("keyboardLayoutSearch", "Reload after changing your compositor's keymap. Direct characters on the base and Shift levels are supported. Compose sequences, dead keys and IME conversion are not supported.")
    }
}
