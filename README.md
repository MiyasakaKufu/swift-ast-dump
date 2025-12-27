# swift-ast-dump

Swift ファイルの AST (抽象構文木) をダンプするツール。ファイル監視機能付きでホットリロードに対応。

![output2](https://github.com/user-attachments/assets/12056541-7f5f-4316-8e8b-0a26766394c0)

## 必要環境

- macOS 13+
- Swift 6.0+

## ビルド

```bash
swift build
```

### 基本的な使い方

引数なしで実行すると、カレントディレクトリに `input.swift` が作成されます（存在しない場合）。

```bash
swift run swift-ast-dump
```

`input.swift` を編集・保存するたびに AST が自動で更新されます。

![output](https://github.com/user-attachments/assets/404e029e-8919-495f-977a-ba383780af6d)

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

SwiftPM プロジェクトでは Xcode のワーキングディレクトリ設定に制限があり、正常に動作しない場合があります。

ターミナルからの実行を推奨します。

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
