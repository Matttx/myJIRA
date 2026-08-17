import SwiftUI

enum JiraDesign {
    static let accent = Color("AccentColor")
    static let foreground = Color("ForegroundColor")
    static let panelRadius: CGFloat = 24
    static let controlRadius: CGFloat = 16
    static let rowRadius: CGFloat = 16
    static let compactRadius: CGFloat = 12
    static let hairline = Color.primary.opacity(0.08)
    static let surface = Color.secondary.opacity(0.08)
    static let subtleSurface = Color.secondary.opacity(0.05)
}

struct JiraStatusColor {
    let accent: Color
    let background: Color
    let border: Color

    static func resolved(for status: String) -> JiraStatusColor {
        let palette: [Color] = [
            Color(red: 124 / 255, green: 167 / 255, blue: 255 / 255),
            Color(red: 145 / 255, green: 199 / 255, blue: 232 / 255),
            Color(red: 151 / 255, green: 151 / 255, blue: 232 / 255),
            Color(red: 184 / 255, green: 159 / 255, blue: 230 / 255),
            Color(red: 203 / 255, green: 166 / 255, blue: 217 / 255),
            Color(red: 218 / 255, green: 190 / 255, blue: 126 / 255),
            Color(red: 196 / 255, green: 181 / 255, blue: 143 / 255),
            Color(red: 158 / 255, green: 172 / 255, blue: 199 / 255)
        ]

        let color = palette[stableIndex(for: status, count: palette.count)]
        return JiraStatusColor(
            accent: color,
            background: color.opacity(0.18),
            border: color.opacity(0.34)
        )
    }

    private static func stableIndex(for value: String, count: Int) -> Int {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hash = normalized.unicodeScalars.reduce(5381) { partial, scalar in
            ((partial << 5) &+ partial) &+ Int(scalar.value)
        }

        return abs(hash) % count
    }
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
    let statusColor: JiraStatusColor?
    let usesTaskCardMaterial: Bool
    @ViewBuilder let content: Content

    init(
        _ label: String? = nil,
        selection: Binding<SelectionValue>,
        isProminent: Bool = false,
        statusColor: JiraStatusColor? = nil,
        usesTaskCardMaterial: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.selection = selection
        self.isProminent = isProminent
        self.statusColor = statusColor
        self.usesTaskCardMaterial = usesTaskCardMaterial
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
            .tint(foregroundStyle)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .font(.paragraphS)
        .foregroundStyle(foregroundStyle)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(backgroundStyle)
        .jiraControlSurface(shape: .capsule, usesTaskCardMaterial: usesTaskCardMaterial)
        .overlay {
            Capsule()
                .stroke(statusColor?.border ?? Color.clear, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay {
            Picker(label ?? "", selection: selection) {
                content
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .buttonStyle(.plain)
            .opacity(0.01)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Capsule())
        }
    }

    private var foregroundStyle: Color {
        if isProminent {
            return .white
        }

        if let statusColor {
            return statusColor.accent
        }

        return Color.primary
    }

    private var backgroundStyle: Color {
        if isProminent {
            return statusColor?.accent.opacity(0.32) ?? JiraDesign.foreground
        }

        if let statusColor {
            return statusColor.background
        }

        return Color.clear
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
            .jiraGlass(shape: .capsule, interactive: true)
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
            .jiraGlass(shape: .capsule, interactive: true)
    }
}

struct JiraPanelModifier: ViewModifier {
    let radius: CGFloat
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .jiraGlass(shape: .roundedRectangle(radius))
    }
}

enum JiraGlassShape {
    case capsule
    case circle
    case roundedRectangle(CGFloat)
}

private struct JiraGlassModifier: ViewModifier {
    let shape: JiraGlassShape
    let tint: Color?
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            let glass = Glass.regular
                .tint(tint)
                .interactive(interactive)

            switch shape {
            case .capsule:
                content
                    .clipShape(Capsule())
                    .glassEffect(glass, in: Capsule())
                    .contentShape(Capsule())
            case .circle:
                content
                    .clipShape(Circle())
                    .glassEffect(glass, in: Circle())
                    .contentShape(Circle())
            case .roundedRectangle(let radius):
                let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
                content
                    .clipShape(shape)
                    .glassEffect(glass, in: shape)
                    .contentShape(shape)
            }
        } else {
            switch shape {
            case .capsule:
                legacyGlass(content, in: Capsule())
            case .circle:
                legacyGlass(content, in: Circle())
            case .roundedRectangle(let radius):
                legacyGlass(content, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
        }
    }

    private func legacyGlass<S: InsettableShape>(_ content: Content, in shape: S) -> some View {
        content
            .clipShape(shape)
            .background(.ultraThinMaterial, in: shape)
            .background(tint?.opacity(0.22) ?? Color.clear, in: shape)
            .overlay {
                shape.strokeBorder(Color.white.opacity(0.24), lineWidth: 0.7)
            }
            .contentShape(shape)
    }
}

private struct JiraTaskCardMaterialModifier: ViewModifier {
    let shape: JiraGlassShape

    @ViewBuilder
    func body(content: Content) -> some View {
        switch shape {
        case .capsule:
            material(content, in: Capsule())
        case .circle:
            material(content, in: Circle())
        case .roundedRectangle(let radius):
            material(content, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }

    private func material<S: InsettableShape>(_ content: Content, in shape: S) -> some View {
        content
            .clipShape(shape)
            .background(.ultraThinMaterial, in: shape)
            .overlay {
                shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 0.7)
            }
            .contentShape(shape)
    }
}

extension View {
    func jiraGlass(
        shape: JiraGlassShape = .roundedRectangle(JiraDesign.compactRadius),
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(JiraGlassModifier(shape: shape, tint: tint, interactive: interactive))
    }

    @ViewBuilder
    func jiraControlSurface(
        shape: JiraGlassShape,
        usesTaskCardMaterial: Bool
    ) -> some View {
        if usesTaskCardMaterial {
            modifier(JiraTaskCardMaterialModifier(shape: shape))
        } else {
            jiraGlass(shape: shape, interactive: true)
        }
    }

    func jiraTaskCardMaterial(shape: JiraGlassShape) -> some View {
        modifier(JiraTaskCardMaterialModifier(shape: shape))
    }

    func jiraCapsuleFieldStyle() -> some View {
        modifier(JiraCapsuleFieldModifier())
    }

    func jiraPanel(radius: CGFloat = JiraDesign.panelRadius, padding: CGFloat = 24) -> some View {
        modifier(JiraPanelModifier(radius: radius, padding: padding))
    }
}
