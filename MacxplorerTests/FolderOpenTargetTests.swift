import XCTest
@testable import Macxplorer

final class FolderOpenTargetTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    func testRealFolderOpensItself() throws {
        let folder = try makeDirectory("Docs")
        let opened = FolderOpenTarget.url(for: folder, opensAsFolder: true)
        XCTAssertEqual(opened?.path, folder.path)
    }

    func testSymlinkToFolderOpensTheTarget() throws {
        let folder = try makeDirectory("Docs")
        let link = root.appendingPathComponent("DocsLink")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: folder)
        let opened = FolderOpenTarget.url(for: link, opensAsFolder: false)
        XCTAssertEqual(samePath(opened), samePath(folder))
    }

    func testFinderAliasToFolderOpensTheTarget() throws {
        let folder = try makeDirectory("Docs")
        let alias = root.appendingPathComponent("DocsAlias")
        let data = try folder.bookmarkData(options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
        try URL.writeBookmarkData(data, to: alias)
        let opened = FolderOpenTarget.url(for: alias, opensAsFolder: false)
        XCTAssertEqual(samePath(opened), samePath(folder))
    }

    func testSymlinkToFileStaysExternal() throws {
        let file = root.appendingPathComponent("note.txt")
        FileManager.default.createFile(atPath: file.path, contents: Data("hi".utf8))
        let link = root.appendingPathComponent("noteLink")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertNil(FolderOpenTarget.url(for: link, opensAsFolder: false))
    }

    func testSymlinkToPackageStaysExternal() throws {
        let app = try makeDirectory("Foo.app")
        let link = root.appendingPathComponent("FooLink.app")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: app)
        XCTAssertNil(FolderOpenTarget.url(for: link, opensAsFolder: false))
    }

    private func makeDirectory(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func samePath(_ url: URL?) -> String? {
        url?.resolvingSymlinksInPath().directoryKey.path
    }
}
