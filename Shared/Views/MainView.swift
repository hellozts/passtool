import SwiftUI

enum SidebarItem: Hashable {
    case all
    case category(UUID)
}

struct MainView: View {
    @ObservedObject var vault = VaultManager.shared
    @State private var selectedItem: SidebarItem? = .all
    @State private var selectedEntryID: UUID?
    @State private var searchText = ""
    @State private var showAddEntry = false
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedItem: $selectedItem, showSettings: $showSettings)
                .navigationTitle("Passtool")
        } content: {
            EntryListView(selectedItem: selectedItem,
                          searchText: searchText,
                          selectedEntryID: $selectedEntryID,
                          showAddEntry: $showAddEntry)
                .navigationTitle(title)
                #if os(macOS)
                .navigationSubtitle(subtitle)
                #endif
        } detail: {
            detailView
        }
        .searchable(text: $searchText, prompt: "搜索标题、用户名、网址")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showAddEntry = true
                } label: {
                    Label("新建条目", systemImage: "plus")
                }
                Button {
                    vault.lock()
                } label: {
                    Label("立即锁定", systemImage: "lock.fill")
                }
                .keyboardShortcut("l", modifiers: [.command])
            }
        }
        .sheet(isPresented: $showAddEntry) {
            EntryEditorView(entry: nil)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if let id = selectedEntryID,
           let entry = vault.data.entries.first(where: { $0.id == id }) {
            EntryDetailView(entry: entry)
        } else {
            EmptyStateView(title: "选择一个条目",
                           systemImage: "lock.shield",
                           description: "从列表中选择条目以查看详情")
        }
    }

    private var title: String {
        switch selectedItem ?? .all {
        case .all: return "全部条目"
        case .category(let id): return vault.categoryName(for: id)
        }
    }

    private var subtitle: String {
        "\(filteredEntries.count) 项"
    }

    private var filteredEntries: [VaultEntry] {
        EntryFilter.filter(vault.data.entries,
                           selectedItem: selectedItem,
                           searchText: searchText,
                           categories: vault.data.categories)
    }
}

/// 侧边栏：分类列表 + 设置入口
struct SidebarView: View {
    @ObservedObject var vault = VaultManager.shared
    @Binding var selectedItem: SidebarItem?
    @Binding var showSettings: Bool

    var body: some View {
        List(selection: $selectedItem) {
            Section {
                Label("全部条目", systemImage: "tray.full")
                    .tag(SidebarItem.all)
            }
            Section("分类") {
                ForEach(vault.data.categories) { cat in
                    Label(cat.name, systemImage: cat.icon)
                        .tag(SidebarItem.category(cat.id))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                showSettings = true
            } label: {
                Label("设置", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
    }
}

/// 条目过滤工具
enum EntryFilter {
    static func filter(_ entries: [VaultEntry],
                       selectedItem: SidebarItem?,
                       searchText: String,
                       categories: [VaultCategory]) -> [VaultEntry] {
        var result = entries
        switch selectedItem ?? .all {
        case .all:
            break
        case .category(let id):
            result = result.filter { $0.categoryID == id }
        }
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            result = result.filter { e in
                e.title.lowercased().contains(q)
                || e.username.lowercased().contains(q)
                || e.url.lowercased().contains(q)
                || e.notes.lowercased().contains(q)
            }
        }
        return result.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}
