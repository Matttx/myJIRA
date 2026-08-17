import SwiftUI

struct KanbanColumnsMenu: View {
    let columns: [KanbanColumn]
    let hiddenColumnTitles: Set<String>
    let onChangeHiddenColumnTitles: (Set<String>) -> Void

    var body: some View {
        Menu {
            ForEach(columns) { column in
                Button(action: { toggle(column.title) }) {
                    Label(
                        column.title,
                        systemImage: hiddenColumnTitles.contains(column.title) ? "square" : "checkmark.square"
                    )
                }
            }

            if !hiddenColumnTitles.isEmpty {
                Divider()
                Button("Show all columns", action: showAll)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "slider.horizontal.3")
                Text(menuTitle)
            }
            .font(.labelS)
            .foregroundStyle(.tertiary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .frame(maxWidth: .infinity, alignment: .trailing)
        .help("Choose which Kanban columns are visible")
    }

    private var menuTitle: String {
        guard !visibleHiddenColumnTitles.isEmpty else { return "Columns" }
        return "Columns · \(visibleHiddenColumnTitles.count) hidden"
    }

    private var visibleHiddenColumnTitles: Set<String> {
        hiddenColumnTitles.intersection(Set(columns.map(\.title)))
    }

    private func toggle(_ title: String) {
        var nextHiddenColumnTitles = hiddenColumnTitles
        if nextHiddenColumnTitles.contains(title) {
            nextHiddenColumnTitles.remove(title)
        } else {
            nextHiddenColumnTitles.insert(title)
        }
        onChangeHiddenColumnTitles(nextHiddenColumnTitles)
    }

    private func showAll() {
        onChangeHiddenColumnTitles([])
    }

}
