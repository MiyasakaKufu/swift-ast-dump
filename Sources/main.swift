import Foundation

let sourceFileURL = URL(fileURLWithPath: #filePath)
let projectDir = sourceFileURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()

guard let config = App.parseArgs(projectDir: projectDir) else {
    exit(0)
}

// ファイルが存在しない場合は作成
FileWatcher.createIfNeeded(at: config.path)

// アプリケーション実行
let app = App(path: config.path, swiftVersion: config.swiftVersion)
await app.run()
