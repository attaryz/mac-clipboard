import Cocoa

@main
struct ClipboardManagerApp {
    static func main() {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.user.clipboardmanager")
        if runningApps.count > 1 {
            print("App is already running.")
            exit(0)
        }
        
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
