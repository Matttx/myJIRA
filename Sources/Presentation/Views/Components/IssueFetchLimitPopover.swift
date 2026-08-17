import SwiftUI

struct IssueFetchLimitPopover: View {
    let selectedLimit: Int
    let onSelectLimit: (Int) -> Void

    var body: some View {
        VStack(spacing: 2) {
            ForEach(IssueFetchPreferences.availableLimits, id: \.self) { limit in
                Button(action: { onSelectLimit(limit) }) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark")
                            .frame(width: 14)
                            .opacity(limit == selectedLimit ? 1 : 0)
                        Text("\(limit) issues")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .frame(width: 180)
    }
}
