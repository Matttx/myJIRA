import AppKit
import CoreText
import SwiftUI

enum JiraFonts {
    static let momoPostScriptName = "MomoTrustDisplay-Regular"
    private static let momoFileName = "MomoTrustDisplay-Regular"
    @MainActor
    private static var hasRegistered = false

    @MainActor
    static func registerIfNeeded() {
        guard !hasRegistered else { return }
        hasRegistered = true
        guard let fontURL = Bundle.main.url(forResource: momoFileName, withExtension: "ttf") else {
            return
        }

        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
    }
}

extension Font {
    private static func jiraDisplay(size: CGFloat) -> Font {
        if NSFont(name: JiraFonts.momoPostScriptName, size: size) != nil {
            return .custom(JiraFonts.momoPostScriptName, size: size)
        }

        return .system(size: size, weight: .regular, design: .rounded)
    }

    private static func jiraParagraph(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static var headingXL: Font { .jiraDisplay(size: 32) }
    static var headingL: Font { .jiraDisplay(size: 24) }
    static var headingM: Font { .jiraDisplay(size: 20) }
    static var headingS: Font { .jiraDisplay(size: 18) }
    static var headingXS: Font { .jiraDisplay(size: 16) }
    static var headingXXS: Font { .jiraDisplay(size: 14) }

    static var labelLBold: Font { .jiraParagraph(size: 16, weight: .semibold) }
    static var labelMBold: Font { .jiraParagraph(size: 14, weight: .semibold) }
    static var labelSBold: Font { .jiraParagraph(size: 12, weight: .semibold) }
    static var labelXSBold: Font { .jiraParagraph(size: 10, weight: .semibold) }

    static var labelL: Font { .jiraParagraph(size: 16, weight: .medium) }
    static var labelM: Font { .jiraParagraph(size: 14, weight: .medium) }
    static var labelS: Font { .jiraParagraph(size: 12, weight: .medium) }
    static var labelXS: Font { .jiraParagraph(size: 10, weight: .medium) }

    static var paragraphL: Font { .jiraParagraph(size: 16) }
    static var paragraphM: Font { .jiraParagraph(size: 14) }
    static var paragraphS: Font { .jiraParagraph(size: 12) }
    static var paragraphXS: Font { .jiraParagraph(size: 10) }

    static var paragraphMSemiBold: Font { .jiraParagraph(size: 14, weight: .semibold) }
    static var paragraphSSemiBold: Font { .jiraParagraph(size: 12, weight: .semibold) }
}
