import Foundation

/// テキスト選択状態
struct Selection {
    var startLine: Int
    var startCol: Int
    var endLine: Int
    var endCol: Int
    var isActive: Bool

    // ダブルクリック単語選択時のアンカー範囲（固定）
    var anchor: Anchor?

    struct Anchor {
        let line: Int
        let startCol: Int
        let endCol: Int
    }

    /// 正規化された範囲を返す（start が end より前になるように）
    var normalized: (startLine: Int, startCol: Int, endLine: Int, endCol: Int) {
        if startLine < endLine || (startLine == endLine && startCol <= endCol) {
            return (startLine, startCol, endLine, endCol)
        } else {
            return (endLine, endCol, startLine, startCol)
        }
    }
}

/// マウスイベントの処理結果
enum MouseEventResult {
    case none
    case selectionChanged
}

/// テキスト選択を管理
final class TextSelection {
    private(set) var selection: Selection?

    // ダブルクリック検出用
    private var lastClickTime: Date?
    private var lastClickPosition: (line: Int, col: Int)?

    /// マウスダウンイベントを処理
    func handleMouseDown(
        contentLine: Int,
        col: Int,
        contentLines: [String]
    ) -> MouseEventResult {
        // 有効範囲外
        guard contentLine >= 0 && contentLine < contentLines.count else {
            selection = nil
            return .none
        }

        let now = Date()
        let isDoubleClick: Bool
        if let lastTime = lastClickTime,
           let lastPos = lastClickPosition,
           now.timeIntervalSince(lastTime) < 0.4,
           lastPos.line == contentLine && abs(lastPos.col - col) <= 1 {
            isDoubleClick = true
        } else {
            isDoubleClick = false
        }

        lastClickTime = now
        lastClickPosition = (line: contentLine, col: col)

        if isDoubleClick {
            // ダブルクリック: 単語を選択
            if let wordRange = findWordBoundaries(in: contentLines, line: contentLine, col: col) {
                selection = Selection(
                    startLine: contentLine,
                    startCol: wordRange.start,
                    endLine: contentLine,
                    endCol: wordRange.end,
                    isActive: true,
                    anchor: Selection.Anchor(
                        line: contentLine,
                        startCol: wordRange.start,
                        endCol: wordRange.end
                    )
                )
                return .selectionChanged
            }
        }

        selection = Selection(
            startLine: contentLine,
            startCol: col,
            endLine: contentLine,
            endCol: col,
            isActive: true,
            anchor: nil
        )
        return .selectionChanged
    }

    /// マウスドラッグイベントを処理
    func handleMouseDrag(
        contentLine: Int,
        col: Int,
        contentLines: [String]
    ) -> MouseEventResult {
        guard var sel = selection, sel.isActive else {
            return .none
        }

        let clampedLine = max(0, min(contentLines.count - 1, contentLine))
        let lineLength = contentLines.isEmpty ? 0 : contentLines[clampedLine].count
        let clampedCol = max(0, min(lineLength, col))

        // ダブルクリック後のドラッグ（単語単位で拡張）
        if let anchor = sel.anchor {
            updateSelectionWithAnchor(
                &sel,
                anchor: anchor,
                targetLine: clampedLine,
                targetCol: clampedCol,
                contentLines: contentLines
            )
        } else {
            // 通常のドラッグ選択
            sel.endLine = clampedLine
            sel.endCol = clampedCol
        }

        selection = sel
        return .selectionChanged
    }

    /// マウスアップイベントを処理
    func handleMouseUp(
        contentLine: Int,
        col: Int,
        contentLines: [String]
    ) -> MouseEventResult {
        guard var sel = selection, sel.isActive else {
            return .none
        }

        let clampedLine = max(0, min(contentLines.count - 1, contentLine))
        let lineLength = contentLines.isEmpty ? 0 : contentLines[clampedLine].count
        let clampedCol = max(0, min(lineLength, col))

        // ダブルクリック後のドラッグ（単語単位で拡張）
        if let anchor = sel.anchor {
            updateSelectionWithAnchor(
                &sel,
                anchor: anchor,
                targetLine: clampedLine,
                targetCol: clampedCol,
                contentLines: contentLines
            )
        } else {
            sel.endLine = clampedLine
            sel.endCol = clampedCol
        }

        sel.isActive = false
        selection = sel

        // クリップボードにコピー
        let selectedText = getSelectedText(from: contentLines)
        if !selectedText.isEmpty {
            copyToClipboard(selectedText)
        }

        return .selectionChanged
    }

    /// 選択をクリア
    func clear() {
        selection = nil
    }

    /// 行に選択ハイライトを適用
    func applyHighlight(to line: String, lineIndex: Int, inverse: String, reset: String) -> String {
        guard let sel = selection else { return line }

        let norm = sel.normalized
        guard lineIndex >= norm.startLine && lineIndex <= norm.endLine else {
            return line
        }

        let chars = Array(line)
        var result = ""

        for (colIndex, char) in chars.enumerated() {
            let isSelected: Bool
            if norm.startLine == norm.endLine {
                isSelected = colIndex >= norm.startCol && colIndex < norm.endCol
            } else if lineIndex == norm.startLine {
                isSelected = colIndex >= norm.startCol
            } else if lineIndex == norm.endLine {
                isSelected = colIndex < norm.endCol
            } else {
                isSelected = true
            }

            if isSelected {
                result += "\(inverse)\(char)\(reset)"
            } else {
                result += String(char)
            }
        }

        return result
    }

    /// 選択範囲のテキストを取得
    func getSelectedText(from contentLines: [String]) -> String {
        guard let sel = selection else { return "" }

        let norm = sel.normalized
        var lines: [String] = []

        for lineIndex in norm.startLine...norm.endLine {
            guard lineIndex >= 0 && lineIndex < contentLines.count else { continue }

            let line = contentLines[lineIndex]
            let chars = Array(line)

            if norm.startLine == norm.endLine {
                let start = max(0, min(chars.count, norm.startCol))
                let end = max(0, min(chars.count, norm.endCol))
                if start < end {
                    lines.append(String(chars[start..<end]))
                }
            } else if lineIndex == norm.startLine {
                let start = max(0, min(chars.count, norm.startCol))
                lines.append(String(chars[start...]))
            } else if lineIndex == norm.endLine {
                let end = max(0, min(chars.count, norm.endCol))
                lines.append(String(chars[..<end]))
            } else {
                lines.append(line)
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    /// アンカーを基準に選択範囲を更新（単語単位）
    ///
    /// アルゴリズム:
    /// - アンカー（ダブルクリックした単語）は常に選択範囲に含まれる
    /// - ターゲットがアンカーより前: ターゲットの単語開始〜アンカーの単語終了
    /// - ターゲットがアンカーより後: アンカーの単語開始〜ターゲットの単語終了
    /// - ターゲットがアンカー範囲内: アンカーの単語のみ
    private func updateSelectionWithAnchor(
        _ sel: inout Selection,
        anchor: Selection.Anchor,
        targetLine: Int,
        targetCol: Int,
        contentLines: [String]
    ) {
        // ターゲットがアンカーより前か後かを判定
        let isBeforeAnchor: Bool
        if targetLine < anchor.line {
            isBeforeAnchor = true
        } else if targetLine > anchor.line {
            isBeforeAnchor = false
        } else {
            // 同一行
            if targetCol < anchor.startCol {
                isBeforeAnchor = true
            } else if targetCol >= anchor.endCol {
                isBeforeAnchor = false
            } else {
                // アンカー範囲内 → アンカーの単語のみ選択
                sel.startLine = anchor.line
                sel.startCol = anchor.startCol
                sel.endLine = anchor.line
                sel.endCol = anchor.endCol
                return
            }
        }

        if isBeforeAnchor {
            // ターゲットがアンカーより前
            // 選択範囲: ターゲットの単語開始 〜 アンカーの単語終了
            if let wordRange = findWordBoundaries(in: contentLines, line: targetLine, col: targetCol) {
                sel.startLine = targetLine
                sel.startCol = wordRange.start
            } else {
                sel.startLine = targetLine
                sel.startCol = targetCol
            }
            sel.endLine = anchor.line
            sel.endCol = anchor.endCol
        } else {
            // ターゲットがアンカーより後
            // 選択範囲: アンカーの単語開始 〜 ターゲットの単語終了
            sel.startLine = anchor.line
            sel.startCol = anchor.startCol
            if let wordRange = findWordBoundaries(in: contentLines, line: targetLine, col: targetCol) {
                sel.endLine = targetLine
                sel.endCol = wordRange.end
            } else {
                sel.endLine = targetLine
                sel.endCol = targetCol
            }
        }
    }

    private func findWordBoundaries(in contentLines: [String], line lineIndex: Int, col: Int) -> (start: Int, end: Int)? {
        guard lineIndex >= 0 && lineIndex < contentLines.count else { return nil }

        let line = contentLines[lineIndex]
        let chars = Array(line)

        guard col >= 0 && col < chars.count else { return nil }

        func isWordChar(_ c: Character) -> Bool {
            c.isLetter || c.isNumber || c == "_"
        }

        guard isWordChar(chars[col]) else { return nil }

        var start = col
        while start > 0 && isWordChar(chars[start - 1]) {
            start -= 1
        }

        var end = col
        while end < chars.count && isWordChar(chars[end]) {
            end += 1
        }

        return (start: start, end: end)
    }

    private func copyToClipboard(_ text: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")
        let pipe = Pipe()
        process.standardInput = pipe
        do {
            try process.run()
            pipe.fileHandleForWriting.write(text.data(using: .utf8) ?? Data())
            pipe.fileHandleForWriting.closeFile()
            process.waitUntilExit()
        } catch {
            // コピー失敗は無視
        }
    }
}
