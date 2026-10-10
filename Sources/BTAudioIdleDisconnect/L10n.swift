import Foundation

/// User-visible strings. The English text is the lookup key and the fallback, so a missing
/// translation (or running outside the .app bundle) still shows English. Translations live in
/// `Resources/<lang>.lproj/Localizable.strings` and are copied into the bundle by
/// `scripts/build-app.sh`; macOS picks the language from the user's preferred languages
/// (English unless Polish ranks higher).
///
/// Numbers are always shown with unit abbreviations ("5 min", "30 s", "40%"), so no string
/// needs plural forms.
enum L10n {
    static var bundle: Bundle = .main

    static func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        guard !args.isEmpty else { return format }
        return String(format: format, locale: Locale.current, arguments: args)
    }
}
