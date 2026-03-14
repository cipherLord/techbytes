import SwiftUI
import CoreText

enum AppFont {
    static let familyName = "Basetica"

    static func register() {
        let fontNames = [
            "Basetica-Thin",
            "Basetica-Light",
            "Basetica-Regular",
            "Basetica-Medium",
            "Basetica-Bold",
            "Basetica-Black"
        ]
        for name in fontNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "otf") ??
                         Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    static func light(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("Basetica-Light", size: size, relativeTo: textStyle)
    }

    static func regular(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("Basetica-Regular", size: size, relativeTo: textStyle)
    }

    static func medium(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("Basetica-Medium", size: size, relativeTo: textStyle)
    }

    static func semiBold(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("Basetica-Bold", size: size, relativeTo: textStyle)
    }

    static func bold(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("Basetica-Black", size: size, relativeTo: textStyle)
    }
}

extension Font {
    static let headline1 = AppFont.bold(28, relativeTo: .largeTitle)
    static let headline2 = AppFont.bold(22, relativeTo: .title2)
    static let headline3 = AppFont.semiBold(18, relativeTo: .headline)
    static let bodyLarge = AppFont.regular(16, relativeTo: .body)
    static let bodyMedium = AppFont.regular(14, relativeTo: .subheadline)
    static let bodySmall = AppFont.regular(12, relativeTo: .footnote)
    static let caption = AppFont.medium(11, relativeTo: .caption)
    static let label = AppFont.medium(13, relativeTo: .caption)
    static let tabLabel = AppFont.medium(10, relativeTo: .caption2)
}
