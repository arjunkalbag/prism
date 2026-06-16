import SwiftUI
import AppKit
import CoreText

/// Bundled custom typefaces.
///
/// - **Typefesse Claire-Obscure** — the `PRISM` wordmark only.
/// - **Pretendard** — everything else (key, Camelot, BPM, labels, lists…).
enum PrismFonts {
    static let displayPostScript = "Typefesse-Claire-Obscure"
    static let bodyPostScript = "Pretendard-Bold"

    /// Register the bundled `.otf` files for this process so `Font.custom`
    /// resolves them regardless of how the app was launched.
    static func registerBundled() {
        let files = ["Typefesse_Claire-Obscure", "Pretendard-Bold"]
        for name in files {
            let url = Bundle.main.url(forResource: name, withExtension: "otf", subdirectory: "Fonts")
                ?? Bundle.main.url(forResource: name, withExtension: "otf")
            guard let url else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Font {
    /// Typefesse Claire-Obscure — the PRISM wordmark only.
    static func prismDisplay(_ size: CGFloat) -> Font { .custom(PrismFonts.displayPostScript, size: size) }
    /// Pretendard — everything else.
    static func prismBody(_ size: CGFloat) -> Font { .custom(PrismFonts.bodyPostScript, size: size) }
}
