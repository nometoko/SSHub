# SSHub

SSHub は、複数の SSH ホスト上で動く学習ジョブや simulation を macOS から管理するためのアプリです。

現在は `SwiftUI + Swift` ベースの最小構成が入っており、今後ここに SSH 接続、ジョブ起動、ログ同期、SQLite 保存を追加していきます。

現在のホスト設定は macOS の Application Support 配下に保存されます。

- `~/Library/Application Support/SSHub/hosts.json`

## Open In Xcode

1. Xcode でこのディレクトリを開く
2. `Package.swift` を読み込む
3. `SSHub` executable target を実行する

## Current Structure

- `Package.swift`: Swift Package 定義
- `Sources/`: SwiftUI アプリ本体
- `requirements.md`: 要件整理
- `mvp-design.md`: MVP 設計
- `tech-stack.md`: 技術スタック方針
