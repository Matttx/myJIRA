import SwiftUI

struct EditableIssueText: View {
    let text: String?
    let placeholder: String
    let font: Font
    let emptyFont: Font
    let lineLimit: ClosedRange<Int>
    let onCommit: (String?) async -> Bool

    @State private var draftText = ""
    @State private var isEditing = false
    @State private var isSaving = false
    @FocusState private var isFocused: Bool

    private var displayText: String {
        let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText?.isEmpty == false ? trimmedText ?? "" : placeholder
    }

    private var isEmpty: Bool {
        text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
    }

    var body: some View {
        Group {
            if isEditing {
                editor
            } else {
                display
            }
        }
        .onChange(of: text) { _, newValue in
            guard !isEditing else { return }
            draftText = newValue ?? ""
        }
    }

    private var display: some View {
        Text(displayText)
            .font(isEmpty ? emptyFont : font)
            .foregroundStyle(isEmpty ? .secondary : .primary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .highPriorityGesture(doubleClickGesture)
            .help("Double-click to edit")
    }

    private var editor: some View {
        TextField(placeholder, text: $draftText, axis: .vertical)
            .font(font)
            .textFieldStyle(.plain)
            .lineLimit(lineLimit)
            .submitLabel(.done)
            .focused($isFocused)
            .disabled(isSaving)
            .onSubmit {
                submit()
            }
            .onExitCommand {
                cancelEditing()
            }
            .task {
                isFocused = true
            }
    }

    private var doubleClickGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                beginEditing()
            }
    }

    private func beginEditing() {
        draftText = text ?? ""
        isEditing = true
    }

    private func submit() {
        guard !isSaving else { return }

        let trimmedText = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextText = trimmedText.isEmpty ? nil : trimmedText

        Task {
            isSaving = true
            let didSave = await onCommit(nextText)
            isSaving = false

            if didSave || nextText == text {
                isEditing = false
                isFocused = false
            }
        }
    }

    private func cancelEditing() {
        draftText = text ?? ""
        isEditing = false
        isFocused = false
    }
}
