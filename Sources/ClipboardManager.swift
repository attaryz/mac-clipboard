import Cocoa
import SwiftUI
import Combine

class ClipboardManager: ObservableObject {
    @Published var clipboardItems: [ClipboardItem] = []
    @Published var groupMode: GroupMode = .time
    @Published var autoPasteEnabled: Bool = true
    @Published var maxItemsLimit: Int = 50
    
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    enum GroupMode: String, Codable, CaseIterable {
        case time = "Time"
        case type = "Type"
        case source = "Source"
        
        var icon: String {
            switch self {
            case .time: return "clock"
            case .type: return "doc.text"
            case .source: return "app"
            }
        }
    }
    
    struct ClipboardItem: Identifiable, Codable {
        let id: UUID
        let content: String
        let timestamp: Date
        let type: ClipboardType
        var isPinned: Bool
        let sourceApp: String?
        
        enum ClipboardType: String, Codable {
            case text
            case link
            case code
            case image
            case file
        }
        
        var displayType: ClipboardType {
            if type != .text { return type }
            if content.hasPrefix("http://") || content.hasPrefix("https://") {
                return .link
            }
            let codePatterns = ["func ", "var ", "let ", "const ", "def ", "class ", "import ", "#include", "{}", "()", ";\n", "=>", "->"]
            if codePatterns.contains(where: { content.contains($0) }) {
                return .code
            }
            return .text
        }
    }
    
    var pinnedItems: [ClipboardItem] {
        clipboardItems.filter { $0.isPinned }
    }
    
    var unpinnedItems: [ClipboardItem] {
        clipboardItems.filter { !$0.isPinned }
    }
    
    var groupedItems: [(String, [ClipboardItem])] {
        let itemsToGroup = clipboardItems
        
        switch groupMode {
        case .time:
            return groupByTime(itemsToGroup)
        case .type:
            return groupByType(itemsToGroup)
        case .source:
            return groupBySource(itemsToGroup)
        }
    }
    
    private func groupByTime(_ items: [ClipboardItem]) -> [(String, [ClipboardItem])] {
        let calendar = Calendar.current
        let now = Date()
        
        var groups: [String: [ClipboardItem]] = [
            "Pinned": [],
            "Today": [],
            "Yesterday": [],
            "This Week": [],
            "Earlier": []
        ]
        
        for item in items {
            if item.isPinned {
                groups["Pinned"]?.append(item)
            } else if calendar.isDateInToday(item.timestamp) {
                groups["Today"]?.append(item)
            } else if calendar.isDateInYesterday(item.timestamp) {
                groups["Yesterday"]?.append(item)
            } else if calendar.isDate(item.timestamp, equalTo: now, toGranularity: .weekOfYear) {
                groups["This Week"]?.append(item)
            } else {
                groups["Earlier"]?.append(item)
            }
        }
        
        let order = ["Pinned", "Today", "Yesterday", "This Week", "Earlier"]
        return order.compactMap { key in
            guard let items = groups[key], !items.isEmpty else { return nil }
            return (key, items)
        }
    }
    
    private func groupByType(_ items: [ClipboardItem]) -> [(String, [ClipboardItem])] {
        let grouped = Dictionary(grouping: items) { $0.displayType }
        let order: [ClipboardItem.ClipboardType] = [.text, .link, .code, .image, .file]
        
        return order.compactMap { type in
            guard let items = grouped[type], !items.isEmpty else { return nil }
            let sorted = items.sorted { ($0.isPinned ? 1 : 0, $0.timestamp) > ($1.isPinned ? 1 : 0, $1.timestamp) }
            return (type.rawValue.capitalized, sorted)
        }
    }
    
    private func groupBySource(_ items: [ClipboardItem]) -> [(String, [ClipboardItem])] {
        let grouped = Dictionary(grouping: items) { $0.sourceApp ?? "Unknown" }
        return grouped.sorted { $0.0 < $1.0 }.map { ($0.0, $0.1) }
    }
    
    init() {
        loadSettings()
        loadSavedItems()
        startMonitoring()
        
        Publishers.Merge3(
            $groupMode.map { _ in () }.eraseToAnyPublisher(),
            $autoPasteEnabled.map { _ in () }.eraseToAnyPublisher(),
            $maxItemsLimit.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
        .sink { [weak self] in
            self?.saveSettings()
        }
        .store(in: &cancellables)
    }
    
    func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.checkForChanges()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkForChanges() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        
        lastChangeCount = pasteboard.changeCount
        
        if let string = pasteboard.string(forType: .string) {
            addItem(content: string, type: .text)
        } else if let url = pasteboard.string(forType: .fileURL) {
            addItem(content: url, type: .file)
        }
    }
    
    private func addItem(content: String, type: ClipboardItem.ClipboardType) {
        guard !content.isEmpty else { return }
        
        if let first = clipboardItems.first, first.content == content && !first.isPinned {
            if let index = clipboardItems.firstIndex(where: { $0.content == content && !$0.isPinned }) {
                let item = clipboardItems.remove(at: index)
                clipboardItems.insert(item, at: 0)
                saveItems()
            }
            return
        }
        
        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName
        
        let item = ClipboardItem(
            id: UUID(),
            content: content,
            timestamp: Date(),
            type: type,
            isPinned: false,
            sourceApp: sourceApp
        )
        
        DispatchQueue.main.async {
            self.clipboardItems.insert(item, at: 0)
            self.enforceItemLimit()
            self.saveItems()
        }
    }
    
    private func enforceItemLimit() {
        while clipboardItems.count > maxItemsLimit {
            if let lastUnpinnedIndex = clipboardItems.lastIndex(where: { !$0.isPinned }) {
                clipboardItems.remove(at: lastUnpinnedIndex)
            } else {
                break
            }
        }
    }
    
    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
        
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            let item = clipboardItems.remove(at: index)
            if item.isPinned {
                let pinnedCount = clipboardItems.filter { $0.isPinned }.count
                clipboardItems.insert(item, at: pinnedCount)
            } else {
                clipboardItems.insert(item, at: 0)
            }
            saveItems()
        }
    }
    
    func togglePin(_ item: ClipboardItem) {
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardItems[index].isPinned.toggle()
            
            clipboardItems.sort { item1, item2 in
                if item1.isPinned != item2.isPinned {
                    return item1.isPinned
                }
                return item1.timestamp > item2.timestamp
            }
            
            saveItems()
        }
    }
    
    func deleteItem(_ item: ClipboardItem) {
        clipboardItems.removeAll { $0.id == item.id }
        saveItems()
    }
    
    func clearAll() {
        clipboardItems.removeAll()
        saveItems()
    }
    
    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("ClipboardManager", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: appFolder.path) {
            try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }
        
        return appFolder.appendingPathComponent("clipboard_history.json")
    }
    
    private var settingsURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("ClipboardManager", isDirectory: true)
        return appFolder.appendingPathComponent("settings.json")
    }
    
    private func saveSettings() {
        let settings = Settings(
            groupMode: groupMode,
            autoPasteEnabled: autoPasteEnabled,
            maxItemsLimit: maxItemsLimit
        )
        
        do {
            let encoded = try JSONEncoder().encode(settings)
            try encoded.write(to: settingsURL, options: .atomic)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
    
    private func loadSettings() {
        do {
            let data = try Data(contentsOf: settingsURL)
            let settings = try JSONDecoder().decode(Settings.self, from: data)
            groupMode = settings.groupMode
            autoPasteEnabled = settings.autoPasteEnabled
            maxItemsLimit = settings.maxItemsLimit
        } catch {
            // Use defaults
        }
    }
    
    struct Settings: Codable {
        var groupMode: GroupMode
        var autoPasteEnabled: Bool
        var maxItemsLimit: Int
    }
    
    private func saveItems() {
        do {
            let encoded = try JSONEncoder().encode(clipboardItems)
            try encoded.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to save clipboard items: \(error)")
        }
    }
    
    private func loadSavedItems() {
        do {
            let data = try Data(contentsOf: storageURL)
            let items = try JSONDecoder().decode([ClipboardItem].self, from: data)
            clipboardItems = items
        } catch {
            clipboardItems = []
        }
    }
}
