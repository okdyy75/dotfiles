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

### 2. コミット処理

- **stageされているファイルがある場合**: 内容を確認した上でコミットする
  - **コミット前にブランチを確認する**: 現在のブランチがデフォルトブランチの場合は直接コミットせず、ユーザーに新しいブランチを切るか確認する
    - 新ブランチを切る場合は、`git pull origin <default-branch>` をしてから `git switch -c <new-branch>` を実行する
    - ブランチ名は変更内容から適切に提案し、ユーザーの承認を得る（例: `feature/xxx`, `fix/yyy`）
  - 作業ブランチ上であることを確認できたら、`git-cz` を使用して件名のみ入力しコミットする
- **stageされているファイルがない場合**: そのまま次のステップへ進む

### 3. 差分の把握

デフォルトブランチとの差分を取得し、変更内容を非エンジニアにも伝わる粒度で要約する。

```bash
git fetch origin <default-branch>
git log origin/<default-branch>..HEAD --no-merges
git diff origin/<default-branch>...HEAD
```

要約する際は、**コードの「何を変更したか」ではなく「どのページ／機能の何を変えたのか」** を意識する。

例: ❌ 「`UserController#index` の N+1 を解消」
    ✅ 「ユーザー一覧画面の表示が遅い問題を改善」

### 4. PRタイトル・本文の作成

`.github/pull_request_template.md` のセクション構成に沿って本文を組み立てる。

- **開発背景**: なぜこの変更が必要か（依頼の経緯・課題感）
- **チケット URL**: 既知のものがあれば記載、無ければ空欄
- **行った事**: どのページ／機能の何を変更したかを非エンジニア視点で箇条書き
- **挙動**: 動画・画像が必要なら添付を促す。手元で取得できる場合は `playwright-mcp` を使う
- **その他のチェックリスト**: テンプレート通りに残す

加えて、本文末尾または「行った事」直下に **変更の確認方法** セクションを追加し、種別ごとに以下の手順を記載する。

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

ユーザーから「OK」「作成して」等の承認が得られたら、HEREDOC で本文を渡して `gh pr create` を実行する。

```bash
gh pr create --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"
```

### 6. 作成後

- 作成されたPRのURLをユーザーに返す
- CIの実行状況を確認する場合は `gh pr checks` を案内する

## 注意事項

- `--no-verify` などフックをスキップするオプションは付けない
- リモートに未push のコミットがある場合は先に `git push -u origin <branch>` を実行する
- 既にPRが存在する場合は新規作成せず、`gh pr view` で確認した上でユーザーに方針を確認する
