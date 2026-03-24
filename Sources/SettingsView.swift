import SwiftUI

struct SettingsView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            
            Divider()
            
            Form {
                Section {
                    Toggle("Auto-paste on select", isOn: $clipboardManager.autoPasteEnabled)
                        .help("Automatically paste the selected item when clicked")
                    
                    Picker("Default group by", selection: $clipboardManager.groupMode) {
                        ForEach(ClipboardManager.GroupMode.allCases, id: \.self) { mode in
                            HStack {
                                Image(systemName: mode.icon)
                                Text(mode.rawValue)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                } header: {
                    Text("General")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Maximum items: \(clipboardManager.maxItemsLimit)")
                            Spacer()
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(clipboardManager.maxItemsLimit) },
                                set: { clipboardManager.maxItemsLimit = Int($0) }
                            ),
                            in: 10...200,
                            step: 10
                        )
                    }
                    
                    Text("Pinned items are not counted towards this limit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Storage")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keyboard Shortcuts")
                                .font(.system(size: 13))
                            
                            Text("Global shortcut to open: Cmd+Shift+V")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Navigation")
                                .font(.system(size: 13))
                            
                            Text("↑/↓ to navigate, Enter to paste, Esc to close")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                } header: {
                    Text("Shortcuts")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Clipboard Manager")
                                .font(.system(size: 13))
                            
                            Text("Version 1.1.0")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    Button("Open Support Folder") {
                        openSupportFolder()
                    }
                    .font(.system(size: 12))
                } header: {
                    Text("About")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
            }
            .formStyle(.grouped)
            .padding(.top, 8)
        }
        .frame(width: 360, height: 480)
    }
    
    private func openSupportFolder() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("ClipboardManager", isDirectory: true)
        
        NSWorkspace.shared.open(appFolder)
    }
}

#Preview {
    SettingsView(clipboardManager: ClipboardManager())
}
