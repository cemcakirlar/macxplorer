import XCTest
@testable import Macxplorer

final class FolderRoutingTests: XCTestCase {
    func testDirectoryKeyKeepsRootAndStripsTrailingSlash() {
        XCTAssertEqual(URL(fileURLWithPath: "/", isDirectory: true).directoryKey.path, "/")
        let slashed = URL(string: "file:///Users/ada/Documents/")
        XCTAssertEqual(slashed?.directoryKey.path, "/Users/ada/Documents")
    }

    func testChainFromRoot() {
        let root = URL(fileURLWithPath: "/", isDirectory: true)
        let target = URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true)
        let chain = FolderRouting.chain(from: root, to: target)
        XCTAssertEqual(chain.map(\.path), ["/", "/Applications", "/Applications/Utilities"])
    }

    func testChainFromHomeAndBestRoot() {
        let root = URL(fileURLWithPath: "/", isDirectory: true)
        let home = URL(fileURLWithPath: "/Users/ada", isDirectory: true)
        let volumes = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        let target = URL(fileURLWithPath: "/Users/ada/Documents", isDirectory: true)

        let chain = FolderRouting.chain(from: home, to: target)
        XCTAssertEqual(chain.map(\.path), ["/Users/ada", "/Users/ada/Documents"])

        let best = FolderRouting.bestRoot(among: [home, root, volumes], for: target)
        XCTAssertEqual(best?.path, "/Users/ada")
    }

    func testBestRootPrefersVolumes() {
        let roots = [
            URL(fileURLWithPath: "/", isDirectory: true),
            URL(fileURLWithPath: "/Users/ada", isDirectory: true),
            URL(fileURLWithPath: "/Volumes", isDirectory: true),
        ]
        let target = URL(fileURLWithPath: "/Volumes/Disk/Photos", isDirectory: true)
        XCTAssertEqual(FolderRouting.bestRoot(among: roots, for: target)?.path, "/Volumes")
    }
}
