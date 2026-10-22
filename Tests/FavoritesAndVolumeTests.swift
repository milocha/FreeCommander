import XCTest

@testable import FreeCommander

@MainActor
final class FavoritesAndVolumeTests: XCTestCase {

    // MARK: - FavoritesStore

    func testFavoritesAddRemoveAndPersistence() throws {
        let suiteName = "fc-tests-favorites-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = FavoritesStore(defaults: defaults)
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Moje Zdjęcia", isDirectory: true)

        store.add(url: folder)
        XCTAssertEqual(store.favorites.count, 1)
        XCTAssertEqual(store.favorites.first?.name, "Moje Zdjęcia")
        XCTAssertTrue(store.contains(url: folder))

        // Duplikat (ta sama ścieżka) nie może się dodać drugi raz.
        store.add(url: folder)
        XCTAssertEqual(store.favorites.count, 1)

        // Nowa instancja na tych samych defaults wczytuje zapisane dane.
        let reloaded = FavoritesStore(defaults: defaults)
        XCTAssertEqual(reloaded.favorites.count, 1)

        reloaded.remove(id: try XCTUnwrap(reloaded.favorites.first).id)
        XCTAssertTrue(reloaded.favorites.isEmpty)
        XCTAssertFalse(reloaded.contains(url: folder))
    }

    func testRootFavoriteIsNamedSlash() {
        let suiteName = "fc-tests-favorites-root-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("brak suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = FavoritesStore(defaults: defaults)
        store.add(url: URL(fileURLWithPath: "/"))
        XCTAssertEqual(store.favorites.first?.name, "/")
    }

    // MARK: - VolumeUsage

    func testVolumeUsagePercentMath() {
        let usage = VolumeUsage(total: 1000, free: 250)
        XCTAssertEqual(usage.used, 750)
        XCTAssertEqual(usage.usedPercent, 75)

        let overflow = VolumeUsage(total: 100, free: 500)
        XCTAssertEqual(overflow.used, 0)
        XCTAssertEqual(overflow.usedPercent, 0)
    }

    func testVolumeUsageForRootVolume() throws {
        let usage = try XCTUnwrap(VolumeInfo.usage(for: URL(fileURLWithPath: "/")))
        XCTAssertGreaterThan(usage.total, 0)
        XCTAssertGreaterThanOrEqual(usage.free, 0)
        XCTAssertGreaterThanOrEqual(usage.usedPercent, 0)
        XCTAssertLessThanOrEqual(usage.usedPercent, 100)
    }
}
