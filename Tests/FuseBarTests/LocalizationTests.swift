import XCTest
@testable import FuseBar

final class LocalizationTests: XCTestCase {
    func testRegionalLanguagesAndOrderedPreferences() {
        for (input, expected) in [("en-GB", "en"), ("zh-CN", "zh-Hans"), ("zh-Hant-TW", "zh-Hans"),
                                  ("ja-JP", "ja"), ("fr-CA", "fr"), ("es-MX", "es"), ("ES_es", "es")] {
            XCTAssertEqual(L10n.resolve([input]), expected)
        }
        XCTAssertEqual(L10n.resolve(["de-DE", "ja-JP", "en-US"]), "ja")
        XCTAssertEqual(L10n.resolve(["fr-FR", "es-ES"]), "fr")
        XCTAssertEqual(L10n.resolve(["de-DE", "ko-KR"]), "en")
        XCTAssertEqual(L10n.resolve([]), "en")
    }

    func testRuntimeLocalizationAndEnglishFallback() {
        XCTAssertEqual(L10n.localized("返回", language: "en"), "Back")
        XCTAssertEqual(L10n.localized("返回", language: "ja"), "戻る")
        XCTAssertEqual(L10n.localized("返回", language: "fr"), "Retour")
        XCTAssertEqual(L10n.localized("返回", language: "es"), "Atrás")
        XCTAssertEqual(L10n.localized("返回", language: "zh-Hans"), "返回")
        XCTAssertEqual(L10n.localized("返回", language: "de"), "Back")
        // User/device names and percent signs are arguments, never format strings.
        let format = L10n.localized("连接到 %@？", language: "en")
        XCTAssertEqual(String(format: format, "Café 100% %@"), "Connect to Café 100% %@?")
    }

    func testBundledCatalogParityAndFormatPlaceholders() throws {
        func catalog(_ language: String, _ table: String) throws -> [String: String] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let data = try Data(contentsOf: URL(fileURLWithPath: path).appendingPathComponent(table + ".strings"))
            return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
        }
        for table in ["Localizable", "InfoPlist"] {
            let english = try catalog("en", table)
            XCTAssertFalse(english.isEmpty)
            for language in L10n.supported {
                let translated = try catalog(language, table)
                XCTAssertEqual(Set(translated.keys), Set(english.keys), language)
                for (key, value) in translated {
                    XCTAssertFalse(value.isEmpty, "\(language): \(key)")
                    XCTAssertEqual(value.components(separatedBy: "%@").count,
                                   english[key]?.components(separatedBy: "%@").count, "\(language): \(key)")
                }
            }
        }
    }
}
