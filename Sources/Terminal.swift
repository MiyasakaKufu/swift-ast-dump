import Foundation

/// ターミナル操作用の Global Actor
@globalActor
actor TerminalActor {
    static let shared = TerminalActor()
}

/// ターミナル制御を担当
@TerminalActor
struct Terminal {
    // MARK: - ANSI Colors
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let dim = "\u{001B}[2m"
    static let cyan = "\u{001B}[36m"
    static let green = "\u{001B}[32m"

    // MARK: - Screen Control
    static let clearScreen = "\u{001B}[2J"
    static let moveCursorHome = "\u{001B}[H"
    static let enterAlternateScreen = "\u{001B}[?1049h"
    static let exitAlternateScreen = "\u{001B}[?1049l"

    // MARK: - State
    nonisolated static let isInteractive = isatty(STDIN_FILENO) != 0

    private static var originalTermios = termios()

    // MARK: - Setup / Restore

    static func setup() {
        guard isInteractive else { return }

        // 代替スクリーンに切り替え
        print(enterAlternateScreen, terminator: "")

        // raw mode に設定
        tcgetattr(STDIN_FILENO, &originalTermios)
        var raw = originalTermios
        raw.c_lflag &= ~UInt(ICANON | ECHO)
        tcsetattr(STDIN_FILENO, TCSANOW, &raw)

        // 非ブロッキングに設定
        let flags = fcntl(STDIN_FILENO, F_GETFL)
        _ = fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK)
    }

    static func restore() {
        guard isInteractive else { return }

        // ターミナル設定を復元
        tcsetattr(STDIN_FILENO, TCSANOW, &originalTermios)

        // 元のスクリーンに戻る
        print(exitAlternateScreen, terminator: "")
        fflush(stdout)
    }

    // MARK: - Screen Operations

    static func clear() {
        guard isInteractive else { return }
        print(clearScreen + moveCursorHome, terminator: "")
    }

    // MARK: - Input

    static func readKey() -> Character? {
        guard isInteractive else { return nil }
        var c: UInt8 = 0
        if read(STDIN_FILENO, &c, 1) == 1 {
            return Character(UnicodeScalar(c))
        }
        return nil
    }
}
