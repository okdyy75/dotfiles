---
name: copilot-implementer
description: |
  GitHub Copilot CLI（`copilot --model claude-sonnet-4.6`）を使用して実装を行う。
  設計済みの仕様に基づき、実装を小さなタスクに分割して進める。
  最小実装(MVP)から段階的に拡張し、差分・コード例・実行手順を提示する。
  トリガー: "copilot実装", "copilotで実装", "copilotに実装させて", "copilot implement"
  使用場面: (1) 機能追加、(2) バグ修正、(3) リファクタリング、(4) 依存追加
---

# Copilot Implementer

GitHub Copilot CLI を使用して実装を実行するスキル。

## 実行コマンド

対象プロジェクトのディレクトリで以下を実行する。

```bash
copilot --silent --no-ask-user --model claude-sonnet-4.6 -p "<request>"
```

`copilot "<request>"` の形は対話セッション起動向けで、単発実行には向かない。

## プロンプトのルール

**重要**: copilot-implementer に渡すリクエストには、以下の指示を必ず含めること：

> 「最小実装（MVP）→ 拡張の順で実装を進めてください。
> 変更ファイル・コード例・実行コマンドまで具体的に提示してください。
> 破壊的変更（DB migration / 大量削除 / 権限変更 / 課金API利用など）が必要な場合は
> `USER APPROVAL REQUIRED` を明示してそこで停止してください。」

## パラメータ

| パラメータ | 説明 |
|-----------|------|
| `--model claude-sonnet-4.6` | 使用モデルを固定 |
| `-p`, `--prompt` | 単発の programmatic 実行を行う |
| `-s`, `--silent` | 余分な統計表示を抑え、応答本文のみを出す |
| `--no-ask-user` | ユーザーへの確認を無効化し、自律的に応答させる |
| `"<request>"` | 実装してほしい内容（日本語可） |

## 出力フォーマット（期待値）

- MVP Plan（最小実装の手順）
- Patch Outline（変更ファイル一覧）
- Code Diffs（抜粋・サンプル）
- How to Run（実行・確認手順）
- Notes（互換性・影響範囲・移行）

## 使用例

### 新機能の実装

```bash
copilot --silent --no-ask-user --model claude-sonnet-4.6 -p "この仕様に基づいて実装してください。最小実装（MVP）→ 拡張の順で、変更ファイル・コード例・実行コマンドまで具体的に提示してください。"
```

### バグ修正

```bash
copilot --silent --no-ask-user --model claude-sonnet-4.6 -p "このバグを修正してください。修正内容と差分、再発防止の観点まで含めて提示してください。"
```

### リファクタリング

```bash
copilot --silent --no-ask-user --model claude-sonnet-4.6 -p "この部分をリファクタしてください。振る舞いを変えずに改善し、差分と影響範囲を明示してください。"
```

### 依存追加

```bash
copilot --silent --no-ask-user --model claude-sonnet-4.6 -p "この依存を追加してください。インストール手順・設定変更・影響範囲まで具体的に提示してください。"
```

## 実行手順

1. 対象プロジェクトのディレクトリで、依頼内容を `copilot --silent --no-ask-user --model claude-sonnet-4.6 -p "<request>"` に渡して実行する
2. プロンプトに「最小実装（MVP）→ 拡張の順で…」の定型文を含める
3. 破壊的変更が含まれる場合は `USER APPROVAL REQUIRED` で停止させる
4. CLI 未導入や認証不足で実行できない場合は、その不足前提を伝える
