import SwiftUI

/// 条目列表
struct EntryListView: View {
    @ObservedObject var vault = VaultManager.shared
    let selectedItem: SidebarItem?
    let searchText: String
    @Binding var selectedEntryID: UUID?
    @Binding var showAddEntry: Bool

    private var entries: [VaultEntry] {
        EntryFilter.filter(vault.data.entries,
                           selectedItem: selectedItem,
                           searchText: searchText,
                           categories: vault.data.categories)
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                EmptyStateView(title: searchText.isEmpty ? "暂无条目" : "无匹配结果",
                               systemImage: searchText.isEmpty ? "tray" : "magnifyingglass",
                               description: searchText.isEmpty ? "点击右上角 + 添加你的第一个条目" : "尝试更换关键词")
            } else {
                List(selection: $selectedEntryID) {
                    ForEach(entries) { entry in
                        NavigationLink(value: entry.id) {
                            EntryRow(entry: entry)
                        }
                    }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            #if os(iOS)
            Button {
                showAddEntry = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .frame(width: 56, height: 56)
                    .background(.tint, in: Circle())
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
            .padding(20)
            #endif
        }
    }
}

struct EntryRow: View {
    let entry: VaultEntry
    @ObservedObject var vault = VaultManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: vault.categoryIcon(for: entry.categoryID))
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title.isEmpty ? "(未命名)" : entry.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                if !entry.username.isEmpty {
                    Text(entry.username)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(vault.categoryName(for: entry.categoryID))
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.secondary.opacity(0.12), in: Capsule())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
