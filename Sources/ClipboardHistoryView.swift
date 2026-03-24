import SwiftUI

struct ClipboardHistoryView: View {
    @StateObject private var clipboardManager = ClipboardManager()
    @State private var searchText = ""
    @State private var selectedItemId: UUID?
    @State private var showSettings = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @FocusState private var isSearchFocused: Bool
    
    var filteredGroups: [(String, [ClipboardManager.ClipboardItem])] {
        if searchText.isEmpty {
            return clipboardManager.groupedItems
        }
        
        let allGroups = clipboardManager.groupedItems
        return allGroups.compactMap { groupName, items in
            let filtered = items.filter { item in
                item.content.localizedCaseInsensitiveContains(searchText)
            }
            return filtered.isEmpty ? nil : (groupName, filtered)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            groupModeSelector
            Divider()
            
            if filteredGroups.isEmpty {
                emptyStateView
            } else {
                clipboardListView
            }
            
            Divider()
            footerView
        }
        .frame(width: 400, height: 600)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            isSearchFocused = true
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(clipboardManager: clipboardManager)
        }
        .overlay(
            ToastView(message: toastMessage, isShowing: $showToast)
                .animation(.easeInOut(duration: 0.2), value: showToast)
        )
        .onAppear {
            setupKeyboardHandling()
        }
    }
    
    private func setupKeyboardHandling() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard !showSettings else { return event }
            
            switch event.keyCode {
            case 125:
                navigateItems(direction: .down)
                return nil
            case 126:
                navigateItems(direction: .up)
                return nil
            case 36:
                if let selectedId = selectedItemId,
                   let item = findItem(by: selectedId) {
                    copyItem(item)
                }
                return nil
            case 53:
                closePopover()
                return nil
            case 18...25:
                if event.modifierFlags.contains(.command) {
                    let index = Int(event.keyCode) - 18
                    selectItemAtIndex(index)
                    return nil
                }
                return event
            case 49:
                if let selectedId = selectedItemId,
                   let item = findItem(by: selectedId) {
                    clipboardManager.togglePin(item)
                    return nil
                }
                return event
            default:
                return event
            }
        }
    }
    
    private enum NavigationDirection {
        case up, down
    }
    
    private func navigateItems(direction: NavigationDirection) {
        let allItems = filteredGroups.flatMap { $0.1 }
        guard !allItems.isEmpty else { return }
        
        if let currentId = selectedItemId,
           let currentIndex = allItems.firstIndex(where: { $0.id == currentId }) {
            let newIndex: Int
            switch direction {
            case .down:
                newIndex = min(currentIndex + 1, allItems.count - 1)
            case .up:
                newIndex = max(currentIndex - 1, 0)
            }
            selectedItemId = allItems[newIndex].id
        } else {
            selectedItemId = allItems.first?.id
        }
    }
    
    private func selectItemAtIndex(_ index: Int) {
        let allItems = filteredGroups.flatMap { $0.1 }
        guard index >= 0 && index < allItems.count else { return }
        selectedItemId = allItems[index].id
        copyItem(allItems[index])
    }
    
    private func findItem(by id: UUID) -> ClipboardManager.ClipboardItem? {
        return filteredGroups.flatMap { $0.1 }.first { $0.id == id }
    }
    
    private func closePopover() {
        NSApp.keyWindow?.close()
    }
    
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "doc.on.clipboard")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Text("Clipboard History")
                    .font(.system(size: 15, weight: .semibold))
                
                Spacer()
                
                Button(action: { showSettings = true }) {
                    Image(systemName: "gear")
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                
                TextField("Search clipboard...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 13))
                    .focused($isSearchFocused)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var groupModeSelector: some View {
        HStack(spacing: 0) {
            ForEach(ClipboardManager.GroupMode.allCases, id: \.self) { mode in
                Button(action: { clipboardManager.groupMode = mode }) {
                    HStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 11))
                        Text(mode.rawValue)
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .foregroundStyle(clipboardManager.groupMode == mode ? .white : .primary)
                    .background(
                        clipboardManager.groupMode == mode
                        ? Color.accentColor
                        : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.6))
            
            Text(searchText.isEmpty ? "No clipboard items" : "No matches found")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            
            if searchText.isEmpty {
                Text("Copy something to get started")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var clipboardListView: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(filteredGroups, id: \.0) { groupName, items in
                    Section {
                        ForEach(items) { item in
                            ClipboardItemRow(
                                item: item,
                                clipboardManager: clipboardManager,
                                isSelected: selectedItemId == item.id,
                                onCopy: {
                                    copyItem(item)
                                },
                                onTogglePin: {
                                    clipboardManager.togglePin(item)
                                },
                                onDelete: {
                                    clipboardManager.deleteItem(item)
                                }
                            )
                            .id(item.id)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(
                                selectedItemId == item.id
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear
                            )
                        }
                    } header: {
                        GroupHeaderView(
                            title: groupName,
                            itemCount: items.count
                        )
                    }
                }
            }
            .listStyle(PlainListStyle())
            .onAppear {
                if let firstGroup = filteredGroups.first,
                   let firstItem = firstGroup.1.first {
                    selectedItemId = firstItem.id
                }
            }
        }
    }
    
    private var footerView: some View {
        HStack {
            let totalItems = clipboardManager.clipboardItems.count
            let pinnedCount = clipboardManager.pinnedItems.count
            
            HStack(spacing: 4) {
                Text("\(totalItems) items")
                    .font(.system(size: 11))
                if pinnedCount > 0 {
                    Text("(\(pinnedCount) pinned)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.secondary)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Export...") {
                    exportHistory()
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .buttonStyle(PlainButtonStyle())
                
                Button("Clear All") {
                    clipboardManager.clearAll()
                }
                .font(.system(size: 11))
                .foregroundStyle(.red.opacity(0.8))
                .buttonStyle(PlainButtonStyle())
                .disabled(clipboardManager.clipboardItems.isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func copyItem(_ item: ClipboardManager.ClipboardItem) {
        clipboardManager.copyToClipboard(item)
        
        if clipboardManager.autoPasteEnabled {
            showToast(message: "Copied & pasted")
            simulatePaste()
        } else {
            showToast(message: "Copied to clipboard")
        }
    }
    
    private func showToast(message: String) {
        toastMessage = message
        showToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showToast = false
        }
    }
    
    private func simulatePaste() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let source = CGEventSource(stateID: .combinedSessionState)
            let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            
            keyVDown?.flags = .maskCommand
            keyVUp?.flags = .maskCommand
            
            keyVDown?.post(tap: .cghidEventTap)
            keyVUp?.post(tap: .cghidEventTap)
        }
    }
    
    private func exportHistory() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "clipboard_history.json"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(clipboardManager.clipboardItems)
                try data.write(to: url)
                showToast(message: "Exported successfully")
            } catch {
                showToast(message: "Export failed")
            }
        }
    }
}

struct GroupHeaderView: View {
    let title: String
    let itemCount: Int
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text("\(itemCount)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary.opacity(0.7))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color(NSColor.controlBackgroundColor))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardManager.ClipboardItem
    @ObservedObject var clipboardManager: ClipboardManager
    let isSelected: Bool
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    @State private var showFullText = false
    @State private var showPreview = false
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: typeIcon)
                .font(.system(size: 14))
                .foregroundStyle(typeColor)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(typeColor.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(item.content)
                    .lineLimit(showFullText ? nil : 2)
                    .font(.system(size: 13))
                    .truncationMode(.tail)
                
                HStack(spacing: 8) {
                    if let sourceApp = item.sourceApp {
                        HStack(spacing: 2) {
                            Image(systemName: "app")
                                .font(.system(size: 8))
                            Text(sourceApp)
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.secondary.opacity(0.7))
                    }
                    
                    Text(formattedDate(item.timestamp))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Button(action: onTogglePin) {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 12))
                        .foregroundStyle(item.isPinned ? Color.accentColor : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(item.isPinned || isHovering ? 1 : 0)
                
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(isHovering ? 1 : 0)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(isHovering ? 1 : 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(
            isSelected
            ? Color.accentColor.opacity(0.1)
            : (isHovering ? Color(NSColor.selectedControlColor).opacity(0.3) : Color.clear)
        )
        .onTapGesture {
            onCopy()
        }
        .onHover { hovering in
            isHovering = hovering
            if hovering && item.content.count > 100 {
                showPreview = true
            } else {
                showPreview = false
            }
        }
        .contextMenu {
            Button("Copy") {
                onCopy()
            }
            
            Button(item.isPinned ? "Unpin" : "Pin") {
                onTogglePin()
            }
            
            Divider()
            
            Button(showFullText ? "Show Less" : "Show Full Text") {
                showFullText.toggle()
            }
            
            Button("Copy & Paste") {
                onCopy()
            }
            
            Divider()
            
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
        .popover(isPresented: $showPreview, attachmentAnchor: .point(.trailing)) {
            TextPreviewPopover(content: item.content)
        }
    }
    
    private var typeIcon: String {
        switch item.displayType {
        case .text:
            return "text.alignleft"
        case .link:
            return "link"
        case .code:
            return "chevron.left.forwardslash.chevron.right"
        case .image:
            return "photo"
        case .file:
            return "doc"
        }
    }
    
    private var typeColor: Color {
        switch item.displayType {
        case .text:
            return .primary
        case .link:
            return .blue
        case .code:
            return .purple
        case .image:
            return .green
        case .file:
            return .orange
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct TextPreviewPopover: View {
    let content: String
    
    var body: some View {
        ScrollView {
            Text(content)
                .font(.system(size: 12, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: 400, maxHeight: 300)
    }
}

struct ToastView: View {
    let message: String
    @Binding var isShowing: Bool
    
    var body: some View {
        if isShowing {
            VStack {
                Spacer()
                
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.8))
                    )
                    .padding(.bottom, 60)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

#Preview {
    ClipboardHistoryView()
}
