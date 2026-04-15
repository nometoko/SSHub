# SSHub Tech Stack

## Direction Reset

SSHub は一旦 `macOS 専用アプリ` として設計し直す。

そのため、これまでの「クロスプラットフォームを意識した Desktop App 構成」は前提から外し、macOS での開発体験、OS 統合、配布のしやすさを優先して技術スタックを再選定する。

## Chosen Stack

現時点の第一候補は以下とする。

- App Platform: macOS native
- UI Framework: SwiftUI
- App Language: Swift
- Local Persistence: SQLite
- SSH Execution Layer: Swift app から `ssh` / `scp` コマンドを利用
- Notification: Slack Incoming Webhook
- Local App Storage: macOS の Application Support 配下

## Why This Stack

### SwiftUI + Swift

- macOS 専用なら最も自然な選択肢
- ネイティブの見た目と操作感を出しやすい
- メニュー、通知、設定画面などの macOS 機能と繋ぎやすい
- 将来的にメニューバー常駐やネイティブ通知も追加しやすい

### macOS Native App

- 「GUI があるものが良い」という要件に素直に合う
- 単一ユーザー向けローカルアプリと相性が良い
- SSH鍵やログキャッシュを macOS ローカルに閉じやすい
- 配布や起動方式も mac 向けに最適化しやすい

### SQLite

- 単一ユーザー向けの MVP に十分
- ホスト設定、ジョブ情報、通知設定、進捗抽出ルールの保存に向く
- クラウドやサーバを用意せずに完結できる

### `ssh` / `scp` の利用

- macOS には OpenSSH が標準で入っている
- MVP 段階では外部ライブラリに強く依存せず始めやすい
- ユーザーの既存 SSH 環境や鍵管理をそのまま活かしやすい

## Rejected Options For Now

### Tauri

- 悪くはないが、macOS 専用に絞るならネイティブ UI の利点を活かしきれない
- Rust と Web UI の二層構成は MVP 初期には少し重い

### Electron

- 実装しやすさはあるが、macOS 専用の第一候補としてはやや過剰
- 配布サイズや常駐時の重さが気になりやすい

### Web App

- GUI 要件は満たせるが、ローカル SSH 鍵や macOS 通知、ローカル保存との相性でネイティブに劣る

## MVP Architecture

MVP では以下の単純な構成を採用する。

- SwiftUI で画面を構築
- アプリ内部でジョブ管理サービスを持つ
- ジョブ管理サービスが `Process` 経由で `ssh` / `scp` を実行する
- リモートホスト上に `.sshub/jobs/<job_id>/` を作って管理ファイルを置く
- ローカル macOS 側に SQLite とログキャッシュを保存する

## Key macOS Components

### UI Layer

- Host List
- Job Dashboard
- Job Detail
- Notification Settings

### Application Layer

- Host 管理
- Job 起動
- Job 監視ポーリング
- ログ同期
- 進捗抽出
- Slack 通知

### System Layer

- `Process` を使った `ssh` 実行
- `Process` を使った `scp` 実行
- SQLite アクセス
- Application Support 配下へのデータ保存

## Suggested Implementation Choices

MVP の具体的な実装候補は以下。

- App project: Xcode の macOS App
- UI: SwiftUI
- Concurrency: Swift Concurrency (`async/await`)
- DB:
  - まずは `SQLite.swift` のような薄いラッパーを検討
  - もしくは `GRDB` も有力
- Logging:
  - ローカル同期ログはプレーンテキストで保存
  - 必要に応じて job 単位でファイル分割

## Recommended DB Choice

現時点では `GRDB` を有力候補とする。

理由。

- Swift での SQLite 利用実績が多い
- 生 SQL と型安全のバランスが良い
- MVP から少し育ったあとも使い続けやすい

ただし、MVP 最優先で依存を減らしたい場合は `SQLite.swift` や直接 SQLite 利用でも良い。

## SSH Strategy

MVP では、SSH は専用 SDK よりもまず `ssh` コマンド呼び出しで始める。

方針。

- 既存の `~/.ssh/config` を使えるようにする
- ホスト登録時は `Host alias` も扱えるようにする
- ジョブ起動時は `ssh <host> 'bash -lc ...'` 形式で実行する
- ログ取得は `ssh` で内容確認しつつ、必要なら `scp` で同期する

これにより、ユーザーの既存 SSH 環境を壊さず MVP を作りやすい。

## Notifications

MVP の通知は以下の2段階で考える。

- 必須: Slack Webhook 通知
- 将来候補: macOS ネイティブ通知

macOS 専用である利点を活かして、将来的には Notification Center 連携を追加しやすい構成にする。

## Local Storage Layout

ローカル保存先は macOS の標準的な場所に寄せる。

例。

- DB: `~/Library/Application Support/SSHub/sshub.sqlite`
- Logs: `~/Library/Application Support/SSHub/logs/`
- App settings: `~/Library/Application Support/SSHub/`

## First Milestone

最初のマイルストーンは以下。

- macOS アプリのプロジェクトを作成する
- SwiftUI でホスト一覧とジョブ一覧の骨格を表示する
- `ssh` コマンドの疎通確認を1回実行できる
- SQLite にホスト情報を1件保存できる

## Next Decisions

次に決めるべき内容。

- DB ライブラリを `GRDB` にするかどうか
- `ssh` 実行ラッパーのインターフェース
- ログ同期方式を `tail` ベースにするか `scp` ベースにするか
- macOS 通知を MVP に入れるか、Slack のみに絞るか
