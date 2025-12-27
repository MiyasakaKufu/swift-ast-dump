import Foundation

/// ターミナル操作用の Global Actor
@globalActor
actor TerminalActor {
    static let shared = TerminalActor()
}

/// キー入力の種類
enum KeyInput: Equatable {
    case char(Character)
    case up
    case down
    case pageUp
    case pageDown
    case scrollUp
    case scrollDown
    case mouseDown(x: Int, y: Int)
    case mouseDrag(x: Int, y: Int)
    case mouseUp(x: Int, y: Int)
}

/// ターミナル制御を担当
@TerminalActor
struct Terminal {
    // MARK: - ANSI Colors
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let dim = "\u{001B}[2m"
    static let inverse = "\u{001B}[7m"
    static let cyan = "\u{001B}[36m"
    static let green = "\u{001B}[32m"

    // MARK: - Screen Control
    static let clearScreen = "\u{001B}[2J"
    static let moveCursorHome = "\u{001B}[H"
    static let enterAlternateScreen = "\u{001B}[?1049h"
    static let exitAlternateScreen = "\u{001B}[?1049l"

    // MARK: - Mouse Tracking
    // 1002: Button-event tracking (press, release, drag with button held)
    // 1006: SGR extended mode (for better coordinate handling)
    static let enableMouseTracking = "\u{001B}[?1002h\u{001B}[?1006h"
    static let disableMouseTracking = "\u{001B}[?1002l\u{001B}[?1006l"

    // MARK: - State
    nonisolated static let isInteractive = isatty(STDIN_FILENO) != 0

    private static var originalTermios = termios()

    // MARK: - Terminal Size

    nonisolated static func getSize() -> (width: Int, height: Int) {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 {
            return (Int(ws.ws_col), Int(ws.ws_row))
        }
        return (80, 24)  // デフォルト値
    }

    // MARK: - Setup / Restore

    static func setup() {
        guard isInteractive else { return }

        // 代替スクリーンに切り替え
        print(enterAlternateScreen, terminator: "")

        // マウストラッキングを有効化
        print(enableMouseTracking, terminator: "")

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

        // マウストラッキングを無効化
        print(disableMouseTracking, terminator: "")

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

    static func readKey() -> KeyInput? {
        guard isInteractive else { return nil }
        var c: UInt8 = 0
        if read(STDIN_FILENO, &c, 1) != 1 {
            return nil
        }

        // ESC シーケンスの処理
        if c == 0x1B {
            var seq: [UInt8] = [0, 0, 0, 0, 0]
            if read(STDIN_FILENO, &seq[0], 1) != 1 { return .char("\u{1B}") }
            if read(STDIN_FILENO, &seq[1], 1) != 1 { return .char("\u{1B}") }

            if seq[0] == Character("[").asciiValue {
                // SGR マウスイベント: ESC [ < Cb ; Cx ; Cy M/m
                if seq[1] == Character("<").asciiValue {
                    return parseMouseEvent()
                }

                // CSI シーケンス
                switch seq[1] {
                case Character("A").asciiValue:
                    return .up
                case Character("B").asciiValue:
                    return .down
                case Character("5").asciiValue:
                    // Page Up: ESC [ 5 ~
                    if read(STDIN_FILENO, &seq[2], 1) == 1, seq[2] == Character("~").asciiValue {
                        return .pageUp
                    }
                case Character("6").asciiValue:
                    // Page Down: ESC [ 6 ~
                    if read(STDIN_FILENO, &seq[2], 1) == 1, seq[2] == Character("~").asciiValue {
                        return .pageDown
                    }
                default:
                    break
                }
            }
            return .char("\u{1B}")
        }

        return .char(Character(UnicodeScalar(c)))
    }

    /// SGR形式のマウスイベントをパース
    /// 形式: Cb ; Cx ; Cy M/m (ESC [ < は既に読み取り済み)
    private static func parseMouseEvent() -> KeyInput? {
        var buffer: [UInt8] = []
        var c: UInt8 = 0
        var isRelease = false

        // M または m が来るまで読み取る
        while read(STDIN_FILENO, &c, 1) == 1 {
            if c == Character("M").asciiValue {
                isRelease = false
                break
            }
            if c == Character("m").asciiValue {
                isRelease = true
                break
            }
            buffer.append(c)
            if buffer.count > 20 { return nil }  // 異常なシーケンス
        }

        // Cb;Cx;Cy をパース
        let str = String(bytes: buffer, encoding: .ascii) ?? ""
        let parts = str.split(separator: ";")
        guard parts.count >= 3,
              let cb = Int(parts[0]),
              let cx = Int(parts[1]),
              let cy = Int(parts[2]) else {
            return nil
        }

        // スクロールイベントの判定 (Cb の bit 6 が立っている)
        if cb & 64 != 0 {
            // bit 0 でスクロール方向を判定
            if cb & 1 == 0 {
                return .scrollUp    // Cb=64
            } else {
                return .scrollDown  // Cb=65
            }
        }

        // 左ボタン (button 0) のみ処理
        let button = cb & 3
        guard button == 0 else { return nil }

        // ドラッグ判定 (bit 5 = 32)
        let isDrag = (cb & 32) != 0

        if isRelease {
            return .mouseUp(x: cx, y: cy)
        } else if isDrag {
            return .mouseDrag(x: cx, y: cy)
        } else {
            return .mouseDown(x: cx, y: cy)
        }
    }
}
