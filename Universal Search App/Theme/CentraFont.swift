import SwiftUI

extension Font {
    private static func centraName(for weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight, .thin, .light:
            return "CentraNo2-Light"
        case .regular:
            return "CentraNo2-Book"
        case .medium, .semibold:
            return "CentraNo2-Medium"
        case .bold, .heavy, .black:
            return "CentraNo2-Bold"
        default:
            return "CentraNo2-Book"
        }
    }

    static func centra(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(centraName(for: weight), size: size)
    }

    #if DEBUG
    static func printAllFonts() {
        for family in UIFont.familyNames.sorted() {
            print("Family: \(family)")
            for name in UIFont.fontNames(forFamilyName: family) {
                print("  \(name)")
            }
        }
    }
    #endif
}
