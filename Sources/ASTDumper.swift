import Foundation
import SwiftSyntax
import SwiftParser

/// AST ダンプを担当
struct ASTDumper {
    let path: String
    var swiftVersion: Parser.SwiftVersion

    init(path: String, swiftVersion: Parser.SwiftVersion = .v6) {
        self.path = path
        self.swiftVersion = swiftVersion
    }

    /// AST をダンプして表示
    func dump() async {
        await printHeader()

        do {
            let source = try String(contentsOfFile: path, encoding: .utf8)
            var parser = Parser(source, swiftVersion: swiftVersion)
            let tree = SourceFileSyntax.parse(from: &parser)
            print(tree.debugDescription)
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
        }
    }

    private func printHeader() async {
        await Terminal.clear()

        let reset = await Terminal.reset
        let cyan = await Terminal.cyan
        let dim = await Terminal.dim

        print("\(cyan)Watching:\(reset) \(path)")

        if Terminal.isInteractive {
            let v5 = await versionLabel(.v5)
            let v6 = await versionLabel(.v6)
            print("\(cyan)Swift version:\(reset) \(v5) Swift 5  \(v6) Swift 6  \(dim)[q] quit\(reset)")
        } else {
            let label = swiftVersion == .v5 ? "Swift 5" : "Swift 6"
            print("\(cyan)Swift version:\(reset) \(label)")
            print("\(dim)(Ctrl+C to exit)\(reset)")
        }

        print("")
    }

    private func versionLabel(_ v: Parser.SwiftVersion) async -> String {
        let isSelected = (v == swiftVersion)
        let label = v == .v5 ? "1" : "2"
        let reset = await Terminal.reset
        let green = await Terminal.green
        let bold = await Terminal.bold
        let dim = await Terminal.dim

        if isSelected {
            return "\(green)\(bold)[\(label)]\(reset)"
        } else {
            return "\(dim)[\(label)]\(reset)"
        }
    }

}
