import XCTest

@testable import FreeCommander

final class FileSystemServiceTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("fc-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        root = base
    }

    override func tearDownWithError() throws {
        if let root {
            try? FileManager.default.removeItem(at: root)
        }
    }

    private func makeFile(_ name: String, bytes: Int = 10) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data(count: bytes).write(to: url)
        return url
    }

    private func makeDirectory(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Lista i sortowanie

    func testListDirectoryHiddenFilesToggle() throws {
        try makeFile("a.txt")
        try makeDirectory("Podfolder")
        try makeFile(".ukryty")

        let visible = try FileSystemService.listDirectorySync(at: root, showHidden: false)
        XCTAssertEqual(Set(visible.map(\.name)), ["a.txt", "Podfolder"])

        let withHidden = try FileSystemService.listDirectorySync(at: root, showHidden: true)
        XCTAssertEqual(Set(withHidden.map(\.name)), ["a.txt", "Podfolder", ".ukryty"])
    }

    func testListDirectoryProperties() throws {
        let file = try makeFile("plik.txt", bytes: 128)
        let items = try FileSystemService.listDirectorySync(at: root, showHidden: false)
        XCTAssertEqual(items.count, 1)
        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item.url.resolvingSymlinksInPath(), file.resolvingSymlinksInPath())
        XCTAssertFalse(item.isDirectory)
        XCTAssertEqual(item.size, 128)
        XCTAssertNotNil(item.modificationDate)
    }

    func testSortDirectoriesFirstWithNameTieBreak() throws {
        try makeFile("beta.txt", bytes: 5)
        try makeFile("Alfa.txt", bytes: 100)
        try makeDirectory("Delta")
        try makeFile("gamma.txt", bytes: 50)

        let sorted = FileSystemService.sort(
            try FileSystemService.listDirectorySync(at: root, showHidden: false),
            field: .name,
            direction: .ascending,
            directoriesFirst: true)

        XCTAssertEqual(sorted.map(\.name), ["Delta", "Alfa.txt", "beta.txt", "gamma.txt"])

        let descending = FileSystemService.sort(
            sorted,
            field: .name,
            direction: .descending,
            directoriesFirst: true)
        XCTAssertEqual(descending.map(\.name), ["Delta", "gamma.txt", "beta.txt", "Alfa.txt"])
    }

    func testSortBySize() throws {
        try makeFile("maly.txt", bytes: 1)
        try makeFile("sredni.txt", bytes: 50)
        try makeFile("duzy.txt", bytes: 500)

        let sorted = FileSystemService.sort(
            try FileSystemService.listDirectorySync(at: root, showHidden: false),
            field: .size,
            direction: .ascending,
            directoriesFirst: true)
        XCTAssertEqual(sorted.map(\.name), ["maly.txt", "sredni.txt", "duzy.txt"])
    }

    // MARK: - Operacje

    func testCopyAndMoveToOtherDirectory() throws {
        let source = try makeFile("raport.txt", bytes: 32)
        let destination = try makeDirectory("cel")

        let copied = try FileSystemService.copySync(from: source, toDirectory: destination)
        XCTAssertTrue(FileManager.default.fileExists(atPath: copied.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path), "kopia nie może znikać ze źródła")
        XCTAssertEqual(try Data(contentsOf: copied.path == source.path ? source : copied).count, 32)

        let moved = try FileSystemService.moveSync(from: source, toDirectory: destination)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.path))
    }

    func testRename() throws {
        let source = try makeFile("stara.txt")
        let renamed = try FileSystemService.renameSync(source, to: "nowa.txt")
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: renamed.path))
    }

    func testRenameOnExistingNameThrows() throws {
        try makeFile("istnieje.txt")
        let source = try makeFile("zrodlo.txt")
        XCTAssertThrowsError(try FileSystemService.renameSync(source, to: "istnieje.txt"))
    }

    func testUniqueURLAddsCounter() throws {
        try makeFile("kopia.txt")
        let second = FileSystemService.uniqueURL(for: "kopia.txt", in: root)
        XCTAssertEqual(second.lastPathComponent, "kopia (2).txt")
        try Data().write(to: second)
        let third = FileSystemService.uniqueURL(for: "kopia.txt", in: root)
        XCTAssertEqual(third.lastPathComponent, "kopia (3).txt")
    }

    func testDeletePermanent() throws {
        let file = try makeFile("kasowany.txt")
        try FileSystemService.deleteSync([file], mode: .permanent)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testMoveFolderIntoOwnSubfolderThrows() throws {
        let folder = try makeDirectory("folder")
        let nested = try makeDirectory("folder/podfolder")
        XCTAssertThrowsError(try FileSystemService.moveSync(from: folder, toDirectory: nested))
        XCTAssertThrowsError(try FileSystemService.copySync(from: folder, toDirectory: nested))
    }

    // MARK: - ZIP

    func testZipUnzipRoundTripSingleFile() async throws {
        let payload = Data("zawartość archiwum".utf8)
        let source = try makeFile("tekst.txt")
        try payload.write(to: source)

        let archive = try await FileSystemService.zip(urls: [source], baseName: "tekst", in: root)
        XCTAssertEqual(archive.pathExtension, "zip")
        XCTAssertTrue(FileManager.default.fileExists(atPath: archive.path))

        let extractDir = try makeDirectory("rozpakowane")
        let extracted = try await FileSystemService.unzip(url: archive, in: extractDir)
        let restored = try Data(contentsOf: extracted.appendingPathComponent("tekst.txt"))
        XCTAssertEqual(restored, payload)
    }

    func testZipMultipleFilesUsesStaging() async throws {
        let first = try makeFile("pierwszy.txt", bytes: 3)
        let second = try makeFile("drugi.txt", bytes: 7)

        let archive = try await FileSystemService.zip(urls: [first, second], baseName: "pakiet", in: root)
        XCTAssertTrue(FileManager.default.fileExists(atPath: archive.path))

        let extractDir = try makeDirectory("wyjscie")
        let extracted = try await FileSystemService.unzip(url: archive, in: extractDir)
        let names = try FileManager.default.contentsOfDirectory(
            at: extracted.appendingPathComponent("pakiet"), includingPropertiesForKeys: nil)
        XCTAssertEqual(Set(names.map(\.lastPathComponent)), ["pierwszy.txt", "drugi.txt"])
    }

    // MARK: - Rozmiar katalogu

    func testDirectorySizeSumsRecursively() async throws {
        try makeFile("a.bin", bytes: 100)
        let nested = try makeDirectory("zagnieżdżony")
        try Data(count: 250).write(to: nested.appendingPathComponent("b.bin"))
        try makeDirectory("pusty")

        let size = await FileSystemService.sizeOfDirectory(at: root)
        XCTAssertEqual(size, 350)
    }

    // MARK: - Lokalizacje systemowe

    func testFavoritesContainHomeAndRoot() {
        let favorites = SystemLocations.favorites
        XCTAssertTrue(favorites.contains { $0.url.standardizedFileURL.path == "/" })
        XCTAssertTrue(favorites.contains { $0.url == FileManager.default.homeDirectoryForCurrentUser })
    }
}
