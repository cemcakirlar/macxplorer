import XCTest
@testable import Macxplorer

final class BrowseViewModeTests: XCTestCase {
    func testStoredFallsBackToDetails() {
        XCTAssertEqual(BrowseViewMode.stored(nil), .details)
        XCTAssertEqual(BrowseViewMode.stored("nope"), .details)
        XCTAssertEqual(BrowseViewMode.stored("icons"), .icons)
        XCTAssertEqual(BrowseViewMode.stored("columns"), .columns)
    }

    @MainActor
    func testAppSettingsDefaultsToDetails() {
        let suite = "BrowseViewModeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.browseView, .details)
    }

    @MainActor
    func testAppSettingsPersistsBrowseView() {
        let suite = "BrowseViewModeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettings(defaults: defaults)
        settings.browseView = .icons
        XCTAssertEqual(AppSettings(defaults: defaults).browseView, .icons)

        settings.browseView = .columns
        XCTAssertEqual(AppSettings(defaults: defaults).browseView, .columns)
    }

    @MainActor
    func testRestoreDefaultsResetsBrowseView() {
        let suite = "BrowseViewModeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettings(defaults: defaults)
        settings.browseView = .columns
        settings.restoreDefaults()
        XCTAssertEqual(settings.browseView, .details)
    }
}
