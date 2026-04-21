import Foundation

enum Language: String {
    case zh = "zh-Hans"
    case en = "en"
}

class LanguageManager {
    static let shared = LanguageManager()
    
    private let languageKey = "AppLanguage"
    
    var currentLanguage: Language {
        get {
            if let saved = UserDefaults.standard.string(forKey: languageKey), let lang = Language(rawValue: saved) {
                return lang
            }
            let preferred = Locale.preferredLanguages.first ?? "zh-Hans"
            if preferred.hasPrefix("en") {
                return .en
            }
            return .zh
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: languageKey)
            NotificationCenter.default.post(name: NSNotification.Name("LanguageChanged"), object: nil)
        }
    }
    
    private let strings: [String: [Language: String]] = [
        "Turn On Virtual Display": [.zh: "开启虚拟显示器", .en: "Turn On Virtual Display"],
        "Turn Off Virtual Display": [.zh: "关闭虚拟显示器", .en: "Turn Off Virtual Display"],
        "Switch to Extended Display": [.zh: "切换为扩展显示器", .en: "Switch to Extended Display"],
        "Switch to Mirrored Display": [.zh: "切换为镜像显示器", .en: "Switch to Mirrored Display"],
        "Turn On PiP": [.zh: "开启画中画", .en: "Turn On PiP"],
        "Turn Off PiP": [.zh: "关闭画中画", .en: "Turn Off PiP"],
        "Open at Login": [.zh: "登录时打开", .en: "Open at Login"],
        "Checking for Updates...": [.zh: "正在检查更新...", .en: "Checking for Updates..."],
        "Downloading Update %d%%": [.zh: "下载更新中 %d%%", .en: "Downloading Update %d%%"],
        "Restart to Update %@": [.zh: "重启更新 %@", .en: "Restart to Update %@"],
        "Update Download Failed": [.zh: "更新下载失败", .en: "Update Download Failed"],
        "About": [.zh: "关于", .en: "About"],
        "Quit": [.zh: "退出", .en: "Quit"],
        "Language": [.zh: "语言", .en: "Language"],
        "Version %@": [.zh: "版本 %@", .en: "Version %@"],
        "Screen Recording Permission": [.zh: "屏幕录制权限提示", .en: "Screen Recording Permission"],
        "Unable to create screen capture input. Please ensure screen recording permissions are granted in System Settings.": [.zh: "无法创建屏幕捕获输入。请在「系统设置 -> 隐私与安全性 -> 屏幕录制」中授予权限后重试。", .en: "Unable to create screen capture input. Please ensure screen recording permissions are granted in System Settings."],
        "Unable to add screen capture to the session.": [.zh: "无法将屏幕捕获添加到会话中。这可能是由于系统限制或权限不足。", .en: "Unable to add screen capture to the session."],
        "OK": [.zh: "好的", .en: "OK"],
        "Update Failed": [.zh: "更新失败", .en: "Update Failed"],
        "Failed to toggle auto-start": [.zh: "切换自启动失败", .en: "Failed to toggle auto-start"]
    ]
    
    func localizedString(for key: String) -> String {
        return strings[key]?[currentLanguage] ?? key
    }
}

extension String {
    var localized: String {
        return LanguageManager.shared.localizedString(for: self)
    }
}
