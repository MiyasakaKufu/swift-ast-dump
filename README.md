# swift-ast-dump

Swift ファイルの AST (抽象構文木) をダンプするツール。ファイル監視機能付きでホットリロードに対応。

## 必要環境

- macOS 13+
- Swift 6.0+

## ビルド

```bash
swift build
```

## 使い方

```
Usage: swift-ast-dump [options] [file]

Options:
  -v, --version <5|6>  Swift language version for parsing
  -h, --help           Show this help

Examples:
  swift-ast-dump                    # Watch input.swift
  swift-ast-dump -v 6               # Parse as Swift 6
  swift-ast-dump path/to/file.swift # Watch specific file
```

### 基本的な使い方

`input.swift` を編集して実行すると、AST がダンプされます。

```bash
swift run swift-ast-dump
```

ファイルを保存するたびに自動で更新されます。

### キー操作 (ターミナル)

ターミナルで実行時は以下のキーで操作できます:

| キー | 動作 |
|------|------|
| `1` | Swift 5 として解析 |
| `2` | Swift 6 として解析 |
| `q` | 終了 |

デフォルトは Swift 6 です。

### Swift バージョンの指定

起動時にバージョンを指定することもできます:

```bash
# Swift 5 として解析
swift run swift-ast-dump -v 5

# Swift 6 として解析
swift run swift-ast-dump -v 6
```

### 別のファイルを指定

```bash
swift run swift-ast-dump path/to/file.swift
swift run swift-ast-dump -v 6 path/to/file.swift
```

## Xcode での実行

Xcode からも実行できます。`input.swift` を編集・保存すると AST が更新されます。

### 注意

- Xcode のコンソールはインタラクティブモードに対応していないため、キー操作はできません。終了は `Ctrl+C` で行います。
- ANSI エスケープシーケンスに対応していないため、更新のたびに出力が追加されていきます。

ターミナルから実行すると、代替スクリーンバッファを使用した TUI モードで動作します。

## 出力例

```
SourceFileSyntax
├─statements: CodeBlockItemListSyntax
│ ╰─[0]: CodeBlockItemSyntax
│   ╰─item: StructDeclSyntax
│     ├─structKeyword: keyword(SwiftSyntax.Keyword.struct)
│     ├─name: identifier("Person")
│     ╰─memberBlock: MemberBlockSyntax
│       ...
```

## 依存ライブラリ

- [swift-syntax](https://github.com/apple/swift-syntax)
