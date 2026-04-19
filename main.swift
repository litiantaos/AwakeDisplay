import Cocoa

// 检查是否已经有实例在运行
let bundleID = Bundle.main.bundleIdentifier ?? "com.litiantao.AwakeDisplay"
let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
if runningApps.count > 1 {
    print("App is already running.")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // This makes it a menu bar app without a Dock icon
app.run()
