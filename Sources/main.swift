import Foundation

let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

guard let config = App.parseArgs(currentDir: currentDir) else {
    exit(0)
}

// ファイルが存在しない場合は作成
FileWatcher.createIfNeeded(at: config.path)

// アプリケーション実行
let app = App(path: config.path, swiftVersion: config.swiftVersion)
await app.run()
