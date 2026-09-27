import Foundation

enum LaunchFolder {
    static func url(
        reopenLastFolder: Bool,
        lastPath: String?,
        home: URL,
        directoryExists: (String) -> Bool
    ) -> URL {
        let homeKey = home.directoryKey
        guard reopenLastFolder, let lastPath, directoryExists(lastPath) else {
            return homeKey
        }
        return URL(fileURLWithPath: lastPath, isDirectory: true).directoryKey
    }
}
