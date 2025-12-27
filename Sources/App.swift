import Foundation
import SwiftParser

/// アプリケーションのメインロジック
@MainActor
final class App {
    private var dumper: ASTDumper
    private var watcher: FileWatcher

    init(path: String, swiftVersion: Parser.SwiftVersion) {
        self.dumper = ASTDumper(path: path, swiftVersion: swiftVersion)
        self.watcher = FileWatcher(path: path)
    }

    /// アプリケーションを実行
    func run() async {
        await Terminal.setup()
        defer {
            Task { @TerminalActor in
                Terminal.restore()
            }
        }

        // 初回実行
        await dumper.dump()

        // メインループ
        while true {
            if let key = await Terminal.readKey() {
                await handleKeyInput(key)
            }

            if watcher.checkForChanges() {
                await dumper.dump()
            }

            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func handleKeyInput(_ key: Character) async {
        switch key {
        case "1":
            dumper.swiftVersion = .v5
            await dumper.dump()
        case "2":
            dumper.swiftVersion = .v6
            await dumper.dump()
        case "q":
            await Terminal.restore()
            exit(0)
        default:
            break
        }
    }
}

// MARK: - CLI Argument Parsing

extension App {
    struct Config {
        let path: String
        let swiftVersion: Parser.SwiftVersion
    }

    static func parseArgs(projectDir: URL) -> Config? {
        var filePath: String?
        var swiftVersion: Parser.SwiftVersion = .v6

        var args = CommandLine.arguments.dropFirst()
        while let arg = args.first {
            args = args.dropFirst()
            switch arg {
            case "-h", "--help":
                printHelp()
                return nil
            case "-v", "--version":
                if let versionStr = args.first {
                    args = args.dropFirst()
                    switch versionStr {
                    case "5": swiftVersion = .v5
                    case "6": swiftVersion = .v6
                    default:
                        fputs("Unknown Swift version: \(versionStr). Use 5 or 6.\n", stderr)
                        exit(1)
                    }
                }
            default:
                if !arg.hasPrefix("-") {
                    filePath = arg
                }
            }
        }

        let path = filePath ?? projectDir.appendingPathComponent("input.swift").path
        return Config(path: path, swiftVersion: swiftVersion)
    }

    private static func printHelp() {
        print("""
        Usage: swift-ast-dump [options] [file]

        Options:
          -v, --version <5|6>  Swift language version for parsing
          -h, --help           Show this help

        Examples:
          swift-ast-dump                    # Watch input.swift
          swift-ast-dump -v 6               # Parse as Swift 6
          swift-ast-dump path/to/file.swift # Watch specific file
        """)
    }
}
