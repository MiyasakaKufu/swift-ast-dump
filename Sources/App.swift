import Foundation
import SwiftParser

/// アプリケーションのメインロジック
@MainActor
final class App {
    private var dumper: ASTDumper
    private var watcher: FileWatcher

    // スクロール状態
    private var scrollOffset: Int = 0
    private var contentLines: [String] = []

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
        await updateContent()
        await render()

        // メインループ
        while true {
            // 全ての入力を読み取り、まとめて処理
            var needsRender = false
            while let key = await Terminal.readKey() {
                let result = await handleKeyInput(key)
                if result == .quit {
                    return
                }
                if result == .needsRender {
                    needsRender = true
                }
            }

            if needsRender {
                await render()
            }

            if watcher.checkForChanges() {
                await updateContent()
                await render()
            }

            try? await Task.sleep(for: .milliseconds(16))  // ~60fps
        }
    }

    private enum HandleResult {
        case none
        case needsRender
        case quit
    }

    private func updateContent() async {
        contentLines = dumper.getContent()
        // スクロール位置を有効範囲内に調整
        scrollOffset = min(scrollOffset, max(0, contentLines.count - 1))
    }

    private func render() async {
        await Terminal.clear()

        let (_, height) = Terminal.getSize()
        let headerLines = await dumper.getHeader()
        let footerHeight = 1
        let contentHeight = height - headerLines.count - footerHeight - 1  // 1行は空行用

        // ヘッダー表示
        for line in headerLines {
            print(line)
        }
        print("")

        // コンテンツ表示（スクロール対応）
        let startIndex = scrollOffset
        let endIndex = min(startIndex + contentHeight, contentLines.count)

        for i in startIndex..<endIndex {
            print(contentLines[i])
        }

        // 空行で埋める
        let printedLines = endIndex - startIndex
        for _ in 0..<(contentHeight - printedLines) {
            print("")
        }

        // フッター表示
        await printFooter(contentHeight: contentHeight)
    }

    private func printFooter(contentHeight: Int) async {
        let reset = await Terminal.reset
        let dim = await Terminal.dim
        let cyan = await Terminal.cyan

        let currentLine = scrollOffset + 1
        let totalLines = contentLines.count
        let maxScroll = max(0, totalLines - contentHeight)

        let scrollInfo: String
        if totalLines <= contentHeight {
            scrollInfo = "All"
        } else if scrollOffset == 0 {
            scrollInfo = "Top"
        } else if scrollOffset >= maxScroll {
            scrollInfo = "Bot"
        } else {
            let percent = Int(Double(scrollOffset) / Double(maxScroll) * 100)
            scrollInfo = "\(percent)%"
        }

        print("\(dim)Line \(currentLine)/\(totalLines) (\(scrollInfo)) \(cyan)[↑↓jk]\(reset)\(dim) scroll \(cyan)[gG]\(reset)\(dim) jump \(cyan)[q]\(reset)\(dim) quit\(reset)", terminator: "")
        fflush(stdout)
    }

    private func handleKeyInput(_ key: KeyInput) async -> HandleResult {
        let (_, height) = Terminal.getSize()
        let headerLines = await dumper.getHeader()
        let footerHeight = 1
        let contentHeight = height - headerLines.count - footerHeight - 1
        let pageSize = max(1, contentHeight - 2)
        let maxScroll = max(0, contentLines.count - contentHeight)

        switch key {
        case .char("1"):
            dumper.swiftVersion = .v5
            scrollOffset = 0
            await updateContent()
            return .needsRender
        case .char("2"):
            dumper.swiftVersion = .v6
            scrollOffset = 0
            await updateContent()
            return .needsRender
        case .char("q"):
            await Terminal.restore()
            return .quit
        case .up, .char("k"):
            if scrollOffset > 0 {
                scrollOffset -= 1
                return .needsRender
            }
        case .down, .char("j"):
            if scrollOffset < maxScroll {
                scrollOffset += 1
                return .needsRender
            }
        case .pageUp, .char("u"):
            let newOffset = max(0, scrollOffset - pageSize)
            if newOffset != scrollOffset {
                scrollOffset = newOffset
                return .needsRender
            }
        case .pageDown, .char("d"):
            let newOffset = min(maxScroll, scrollOffset + pageSize)
            if newOffset != scrollOffset {
                scrollOffset = newOffset
                return .needsRender
            }
        case .char("g"):
            if scrollOffset != 0 {
                scrollOffset = 0
                return .needsRender
            }
        case .char("G"):
            if scrollOffset != maxScroll {
                scrollOffset = maxScroll
                return .needsRender
            }
        case .scrollUp:
            if scrollOffset > 0 {
                scrollOffset = max(0, scrollOffset - 3)
                return .needsRender
            }
        case .scrollDown:
            if scrollOffset < maxScroll {
                scrollOffset = min(maxScroll, scrollOffset + 3)
                return .needsRender
            }
        default:
            break
        }
        return .none
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
