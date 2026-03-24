import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var clipboardManager: ClipboardManager!
    var eventMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        clipboardManager = ClipboardManager()
        
        let contentView = ClipboardHistoryView()
            .environmentObject(clipboardManager)
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 600)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.contentViewController?.view.window?.backgroundColor = NSColor.controlBackgroundColor
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        setupGlobalHotkey()
        setupClickOutsideMonitor()
    }
    
    @objc func togglePopover() {
        if statusItem.button != nil {
            if popover.isShown {
                closePopover()
            } else {
                showPopover()
            }
        }
    }
    
    func showPopover() {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            startClickOutsideMonitor()
        }
    }
    
    func closePopover() {
        popover.performClose(nil)
        stopClickOutsideMonitor()
    }
    
    func setupGlobalHotkey() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) &&
               event.modifierFlags.contains(.shift) &&
               event.keyCode == 9 {
                DispatchQueue.main.async {
                    self.togglePopover()
                }
            }
        }
    }
    
    func setupClickOutsideMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.popover.isShown else { return }
            
            if let popoverWindow = self.popover.contentViewController?.view.window {
                let clickLocation = event.locationInWindow
                let popoverFrame = popoverWindow.frame
                
                if !popoverFrame.contains(clickLocation) {
                    DispatchQueue.main.async {
                        self.closePopover()
                    }
                }
            }
        }
    }
    
    func startClickOutsideMonitor() {}
    
    func stopClickOutsideMonitor() {}
    
    func applicationWillTerminate(_ notification: Notification) {
        clipboardManager.stopMonitoring()
        
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
