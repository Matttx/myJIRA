import AppKit
import SwiftUI

struct IssueFetchLimitTitleMenu: NSViewRepresentable {
    let title: String
    let issueFetchLimit: Int
    let onSelectLimit: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(issueFetchLimit: issueFetchLimit, onSelectLimit: onSelectLimit)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.target = context.coordinator
        button.action = #selector(Coordinator.showPopover(_:))
        button.setButtonType(.momentaryChange)
        button.isBordered = false
        button.focusRingType = .none
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.image = NSImage(systemSymbolName: "list.number", accessibilityDescription: nil)
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = "Change the number of issues displayed"
        updateButton(button)
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.issueFetchLimit = issueFetchLimit
        context.coordinator.onSelectLimit = onSelectLimit
        updateButton(button)
    }

    private func updateButton(_ button: NSButton) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left

        let text = NSMutableAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle
            ]
        )
        text.append(
            NSAttributedString(
                string: "\nShowing latest \(issueFetchLimit) issues",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 10),
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: paragraphStyle
                ]
            )
        )

        button.attributedTitle = text
        button.setAccessibilityLabel("\(title), showing latest \(issueFetchLimit) issues")
        button.sizeToFit()
    }

    @MainActor
    final class Coordinator: NSObject {
        var issueFetchLimit: Int
        var onSelectLimit: (Int) -> Void
        private let popover = NSPopover()

        init(issueFetchLimit: Int, onSelectLimit: @escaping (Int) -> Void) {
            self.issueFetchLimit = issueFetchLimit
            self.onSelectLimit = onSelectLimit
            super.init()
            popover.behavior = .transient
            popover.animates = true
        }

        @objc func showPopover(_ sender: NSButton) {
            let content = IssueFetchLimitPopover(
                selectedLimit: issueFetchLimit,
                onSelectLimit: { [weak self] limit in
                    self?.popover.close()
                    self?.onSelectLimit(limit)
                }
            )
            popover.contentViewController = NSHostingController(rootView: content)
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
        }
    }
}
