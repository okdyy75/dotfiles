---
name: pr-create
description: 現在のブランチの変更内容を元に、GitHubのPull Requestを作成する。タイトル・本文を提示し承認を得てから`gh pr create`を実行する。
user-invocable: true
---

# PR作成

現在のブランチの変更内容を元にPull Requestを作成します。
原則 `.github/pull_request_template.md` のフォーマットを元に本文を作成してください。

## 作成手順

### 1. 事前確認

以下を並列で実行し、現在のブランチ状態を把握する。

- `git status` で stage / 未追跡ファイルを確認
- `git branch --show-current` で現在のブランチ名を確認
- `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` でデフォルトブランチ名を取得
- `.github/pull_request_template.md` を読み込み、本文のフォーマットを確認
- PR の base branch を決める。原則はデフォルトブランチ。stacked PR の場合だけ前段 PR branch を base にする

### 2. コミット処理

- **stageされているファイルがある場合**: 内容を確認した上でコミットする
  - **コミット前にブランチを確認する**: 現在のブランチがデフォルトブランチの場合は直接コミットせず、ユーザーに新しいブランチを切るか確認する
    - 新ブランチを切る場合は、`git pull origin <default-branch>` をしてから `git switch -c <new-branch>` を実行する
    - ブランチ名は変更内容から適切に提案し、ユーザーの承認を得る（例: `feature/xxx`, `fix/yyy`）
  - 作業ブランチ上であることを確認できたら、`git-cz` を使用して件名のみ入力しコミットする
- **stageされているファイルがない場合**: そのまま次のステップへ進む

### 3. 差分の把握

base branch との差分を取得し、変更内容を非エンジニアにも伝わる粒度で要約する。

```bash
git fetch origin <base-branch>
git log origin/<base-branch>..HEAD --no-merges
git diff origin/<base-branch>...HEAD
git diff --name-only origin/<base-branch>...HEAD
git diff --shortstat origin/<base-branch>...HEAD
```

PR size gate を作成前に確認する。

- `git diff --shortstat origin/<base-branch>...HEAD` で files / insertions を確認する
- `files > 50` または `insertions > 1500` の場合は PR を作成せず、分割案を提示してユーザー確認を取る
- `git diff --name-only origin/<base-branch>...HEAD` は PR 本文の「影響パス」に使う

要約する際は、**コードの「何を変更したか」ではなく「どのページ／機能の何を変えたのか」** を意識する。

例: ❌ 「`UserController#index` の N+1 を解消」
    ✅ 「ユーザー一覧画面の表示が遅い問題を改善」

### 4. PRタイトル・本文の作成

`.github/pull_request_template.md` のセクション構成に沿って本文を組み立てる。

- **開発背景**: なぜこの変更が必要か（依頼の経緯・課題感）
- **チケット URL**: 必ず `issue URL` / `#PR番号` / `なし` のいずれかを書く。空欄にしない
- **行った事**: どのページ／機能の何を変更したかを非エンジニア視点で箇条書き。数行程度にまとめる
- **影響パス**: `git diff --name-only origin/<base-branch>...HEAD` から主要な変更パスを bullet で最低 1 つ書く。placeholder の `-` だけを残さない
- **挙動(動作確認)**: 挙動の確認方法を記載
- **その他のチェックリスト**: テンプレート通りに残す

PR 作成前に本文を自己検査する。

- `## チケット URL` セクションに `issue URL` / `#PR番号` / `なし` があること
- `## 影響パス` セクションに `- src/...` 形式の bullet が最低 1 つあること
- PR size が `files <= 50` かつ `insertions <= 1500` であること


# 挙動(動作確認)

| 変更種別 | 記載する内容 |
|---------|-------------|
| バッチ修正 | バッチの実行コマンド・実行手順 |
| API修正 | 実行すべき RSpec のファイルパス（例: `docker compose exec api rspec spec/requests/xxx_spec.rb`） |
| 画面修正 | 対象ページのURL／導線、操作手順 |

変更が複数種別にまたがる場合は、それぞれの確認方法を併記する。

### 5. 承認フロー（重要）

**`gh pr create` は承認を得るまで絶対に実行しない。**

以下のフォーマットでタイトルと本文をユーザーに提示し、承認・修正指示を待つ。

```
## 提案するPR

### タイトル
<title>

### 本文
<body>
```

ユーザーから「OK」「作成して」等の承認が得られたら、本文を一時ファイルに保存して `--body-file` で `gh pr create` を実行する。

```bash
gh pr create --base <base-branch> --title "<title>" --body-file /private/tmp/<branch-name>-pr-body.md
```

### 6. 作成後

- 作成されたPRのURLをユーザーに返す
- `gh pr checks <PR番号>` で `check` が PR description / PR size エラーになっていないか確認する

## 注意事項

- `--no-verify` などフックをスキップするオプションは付けない
- リモートに未push のコミットがある場合は先に `git push -u origin <branch>` を実行する
- 既にPRが存在する場合は新規作成せず、`gh pr view` で確認した上でユーザーに方針を確認する。本文を更新する場合も `## チケット URL` / `## 影響パス` / PR size の自己検査を同じように行う
