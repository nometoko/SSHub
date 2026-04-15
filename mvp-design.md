# SSHub MVP Design

## Goal

要件で整理した内容をもとに、まず実装すべきMVPの範囲と設計方針を明確にする。

このMVPでは、以下を最短で実現することを目的とする。

- 複数SSHホストを登録できる
- SSHub経由でジョブを起動できる
- 起動したジョブの状態を一覧で監視できる
- 標準出力・標準エラーを確認できる
- ログ解析ベースで進捗を確認できる
- 完了・失敗時にSlack通知できる

## Product Direction

- 単一ユーザー向け
- GUIあり
- macOS向けデスクトップアプリ
- クラウド前提ではなく、ローカルPC中心で完結
- SSH先の任意プロセス全体を汎用管理するより、まずは「SSHubから起動したジョブ」の管理に集中する

## Recommended App Shape

MVPでは、以下の構成を第一候補とする。

- macOS ネイティブアプリ
- アプリ内部にジョブ管理ロジックを持つ
- UIからローカルのアプリケーション層を直接操作する
- アプリケーション層がSSH接続、ジョブ起動、ログ取得、通知送信を担当

理由は以下の通り。

- GUI要件を満たしやすい
- 単一ユーザー向けと相性が良い
- macOSでの配布と運用をシンプルにしやすい
- SSH鍵やログ保存をローカルPC内で閉じやすい
- Webサービス基盤なしで始められる

候補技術の例。

- SwiftUI + Swift
- Electron + React
- Tauri + React

macOS 専用前提のため、MVP では `SwiftUI + Swift` を第一候補とする。

## MVP Features

### 1. Host Management

- SSHホストを登録する
- 登録済みホストを一覧表示する
- 接続テストを行う
- ホスト情報を編集・削除する

登録項目。

- 表示名
- ホスト名またはIP
- ポート
- ユーザー名
- 認証方式
- 秘密鍵パス

MVPでは、認証方式はまず `公開鍵認証` を中心にする。

### 2. Job Launch

- SSHubのUIから対象ホストを選んでコマンドを実行する
- 実行時にジョブ名を付けられる
- ワーキングディレクトリを指定できる
- 実行コマンドを保存する

MVPでの前提。

- SSHub経由で起動したジョブのみを管理対象とする
- 起動時にジョブIDを採番する
- リモートでジョブをバックグラウンド実行する
- PID、開始時刻、ログ出力先を記録する

### 3. Job Monitoring

- ジョブ一覧を表示する
- ホストごと、ステータスごとに絞り込む
- ジョブの状態を定期更新する

表示項目。

- ジョブ名
- ホスト名
- ステータス
- 開始時刻
- 経過時間
- PID
- 最終ログ時刻
- 進捗サマリ

ステータス候補。

- queued
- running
- completed
- failed
- stopped
- unknown

### 4. Job Detail

- 基本情報を表示する
- 標準出力ログを表示する
- 標準エラーログを表示する
- 最新ログを追尾表示する
- エラー時に終了コードと直近ログを表示する

### 5. Progress Parsing

進捗取得はログ解析ベースとする。

MVPでは、以下の2段構成にする。

- デフォルトでは単純なログ表示のみ
- 必要なジョブに対して進捗抽出ルールを設定可能にする

進捗抽出ルールの例。

- `Epoch 3/10`
- `step=1200/5000`
- `progress: 42%`

抽出対象。

- 現在値
- 最大値
- 進捗率
- 任意メッセージ

MVPでは、複雑な推定よりも「拾えたものを素直に表示する」方針にする。

### 6. Notifications

- Slack Webhook を設定できる
- ジョブ完了時に通知する
- ジョブ失敗時に通知する

通知内容。

- ジョブ名
- ホスト名
- ステータス
- 開始時刻
- 終了時刻
- 実行時間
- 失敗時の末尾ログ抜粋

### 7. Stop Job

- 実行中ジョブを停止できる
- 停止時は確認ダイアログを表示する
- 通常は `SIGTERM` を送り、必要なら `SIGKILL` を選べる余地を残す

MVPでは、まずは安全側として通常停止のみを提供しても良い。

## Non-Goals for MVP

以下はMVPでは扱わない。

- 複数ユーザー対応
- クラウド同期
- 学習コード用SDK
- GPU/CPU/メモリ使用率の可視化
- SlurmやKubernetesなど外部スケジューラとの本格統合
- 実験比較機能
- 高度なジョブ依存関係管理

## Suggested System Architecture

## Components

### 1. Desktop UI

役割。

- ホスト一覧画面
- ジョブ一覧画面
- ジョブ詳細画面
- 通知設定画面
- macOS上での常用を前提にした操作体験

### 2. Local Application Backend

役割。

- SSH接続管理
- ジョブ起動処理
- 定期ポーリング
- ログ同期
- 状態判定
- Slack通知
- ローカルDB管理
- macOSローカル環境への設定・キャッシュ保存

### 3. Remote Host

役割。

- ジョブ実行
- stdout / stderr をファイルに出力
- PID管理
- 終了コード保存

## Runtime Flow

### Job Launch Flow

1. ユーザーがホストとコマンドを指定してジョブ開始
2. ローカルバックエンドがジョブIDを発行
3. SSHで接続し、リモートでジョブをバックグラウンド起動
4. stdout / stderr の保存先を決める
5. PIDと開始時刻を取得してローカルDBへ保存
6. UI上で `running` として表示

### Monitoring Flow

1. バックエンドが一定間隔で各ジョブをポーリング
2. PID存在確認、終了コード確認、ログ更新確認を行う
3. 新規ログを取得してローカルへ反映
4. ログ解析ルールがあれば進捗を更新
5. 状態変化があればDB更新と通知送信

## Remote Execution Strategy

MVPでは、リモートジョブ起動方法をシンプルに統一する。

方針。

- `bash -lc` でコマンド実行
- `nohup` または同等手段でセッション切断後も継続
- stdout / stderr を明示的なファイルへリダイレクト
- PIDをファイルに保存
- 終了コードを別ファイルに保存

管理用ファイルの例。

- `~/.sshub/jobs/<job_id>/stdout.log`
- `~/.sshub/jobs/<job_id>/stderr.log`
- `~/.sshub/jobs/<job_id>/pid`
- `~/.sshub/jobs/<job_id>/exit_code`
- `~/.sshub/jobs/<job_id>/meta.json`

この方式の利点。

- tmuxやscreen必須にしなくてよい
- MVPとして実装が単純
- 再接続後も状態確認しやすい

## Local Persistence

ローカルPCにアプリ用データを保存する。

保存対象。

- ホスト設定
- ジョブメタデータ
- ローカルに同期したログのオフセット情報
- 通知設定
- 進捗抽出ルール

候補。

- SQLite

MVPでは `SQLite` を第一候補とする。

## Draft Data Model

### hosts

- id
- name
- hostname
- port
- username
- auth_type
- key_path
- created_at
- updated_at

### jobs

- id
- host_id
- name
- command
- cwd
- remote_job_dir
- remote_pid
- status
- started_at
- finished_at
- exit_code
- last_log_at
- progress_current
- progress_total
- progress_percent
- progress_message
- created_at
- updated_at

### notification_settings

- id
- slack_webhook_url
- notify_on_completed
- notify_on_failed

### progress_patterns

- id
- name
- regex
- value_group_name
- total_group_name
- percent_group_name
- message_group_name

## MVP Screens

### 1. Host List Screen

- ホスト一覧
- 追加ボタン
- 接続テスト

### 2. Job Dashboard Screen

- 実行中ジョブ一覧
- 完了 / 失敗ジョブ一覧
- フィルタ
- 手動更新
- ジョブ起動ボタン

### 3. Job Detail Screen

- ジョブ基本情報
- stdout タブ
- stderr タブ
- 進捗表示
- 停止ボタン

### 4. Notification Settings Screen

- Slack Webhook URL 設定
- 通知イベントのON/OFF

## Risks and Design Notes

### 1. PIDだけでは不十分な場合がある

- 子プロセスを持つジョブでは停止や状態判定が難しい可能性がある
- MVPではまず単純な単一ジョブ起動を前提にする

### 2. ログ形式のばらつき

- 進捗抽出は万能ではない
- 初期段階では「ログ閲覧ができること」を主価値にする

### 3. SSH切断や瞬断

- 一時失敗時は `unknown` にせずリトライ余地を持つ
- 連続失敗した場合のみ警告表示する設計が望ましい

### 4. ローカル保存とリモート保存の責務

- 真正な実行ログはリモートに置く
- UI表示用のキャッシュやメタデータはローカルに置く

### 5. macOS前提で簡略化できる点

- 配布対象をmacOSに限定できる
- OS差分対応をMVPで考えなくてよい
- 将来的にmacOSネイティブ通知との連携も検討しやすい

## Implementation Order

1. ホスト管理
2. SSH接続テスト
3. リモートジョブ起動
4. ジョブ一覧取得
5. ログ表示
6. 停止機能
7. Slack通知
8. 進捗抽出

## Next Decisions

次に決めるべき内容。

- デスクトップ技術の最終選定
- バックエンド言語の選定
- SSHライブラリの選定
- リモート起動コマンド仕様の詳細
- ローカルDBスキーマの確定
