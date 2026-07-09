import SwiftUI

enum JiraDesign {
    static let accent = Color.black
    static let foreground = Color(red: 254 / 255, green: 255 / 255, blue: 255 / 255)
    static let panelRadius: CGFloat = 24
    static let controlRadius: CGFloat = 16
    static let rowRadius: CGFloat = 16
    static let compactRadius: CGFloat = 12
    static let hairline = Color.primary.opacity(0.08)
    static let surface = Color.secondary.opacity(0.08)
    static let subtleSurface = Color.secondary.opacity(0.05)
}

extension Color {
    static var foreground: Color { JiraDesign.foreground }
}

struct JiraPrimaryButtonStyle: ButtonStyle {
    let expandsToMaxWidth: Bool

    init(expandsToMaxWidth: Bool = true) {
        self.expandsToMaxWidth = expandsToMaxWidth
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.labelMBold)
            .foregroundStyle(JiraDesign.foreground)
            .frame(maxWidth: expandsToMaxWidth ? .infinity : nil)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(JiraDesign.accent.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(.capsule)
            .contentShape(.capsule)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct JiraInlineValuePickerRow<SelectionValue: Hashable, Content: View>: View {
    let label: String?
    let selection: Binding<SelectionValue>
    let isProminent: Bool
    @ViewBuilder let content: Content

    init(
        _ label: String? = nil,
        selection: Binding<SelectionValue>,
        isProminent: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.selection = selection
        self.isProminent = isProminent
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 4) {
            if let label {
                Text(label)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Picker(label ?? "", selection: selection) {
                content
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .buttonStyle(.plain)
        }
        .font(.paragraphS)
        .foregroundStyle(isProminent ? JiraDesign.accent : Color.primary)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isProminent ? JiraDesign.foreground : JiraDesign.surface)
        .clipShape(.capsule)
    }
}

struct JiraSecondaryButtonStyle: ButtonStyle {
    let expandsToMaxWidth: Bool

    init(expandsToMaxWidth: Bool = true) {
        self.expandsToMaxWidth = expandsToMaxWidth
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.labelMBold)
            .foregroundStyle(.primary.opacity(configuration.isPressed ? 0.82 : 1))
            .frame(maxWidth: expandsToMaxWidth ? .infinity : nil)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(JiraDesign.surface)
            .clipShape(.capsule)
            .contentShape(.capsule)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct JiraCapsuleFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.paragraphM)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(JiraDesign.surface)
            .clipShape(.capsule)
    }
}

struct JiraPanelModifier: ViewModifier {
    let radius: CGFloat
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(JiraDesign.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func jiraCapsuleFieldStyle() -> some View {
        modifier(JiraCapsuleFieldModifier())
    }

    func jiraPanel(radius: CGFloat = JiraDesign.panelRadius, padding: CGFloat = 24) -> some View {
        modifier(JiraPanelModifier(radius: radius, padding: padding))
    }
}
