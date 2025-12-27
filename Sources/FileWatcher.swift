import Foundation

/// ファイルの変更を監視
struct FileWatcher {
    let path: String
    private var lastModified: Date?

    init(path: String) {
        self.path = path
        self.lastModified = Self.getModificationDate(of: path)
    }

    /// ファイルが変更されたかチェック
    mutating func checkForChanges() -> Bool {
        let current = Self.getModificationDate(of: path)
        if current != lastModified {
            lastModified = current
            return true
        }
        return false
    }

    private static func getModificationDate(of path: String) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date
    }

    /// ファイルが存在しない場合にサンプルを作成
    static func createIfNeeded(at path: String) {
        guard !FileManager.default.fileExists(atPath: path) else { return }

        let sample = """
        struct Hello {
            let message: String
        }
        """
        try? sample.write(toFile: path, atomically: true, encoding: .utf8)
        fputs("Created: \(path)\n", stderr)
    }
}
