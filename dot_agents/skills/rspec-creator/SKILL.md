---
name: rspec-creator
description: RSpec作成スキル。対象ファイルを分析し、Model/GraphQL/Job/Libのテストファイルを作成してdocker環境でテスト実行・検証まで行う。
---

# RSpec テスト作成スキル

現在のブランチの変更差分のファイルに対して、RSpecテストを作成してください

## 基本方針

- PJ内にテストガイドラインがある場合は、必ずそれに準じてください（例: `docs/testing-guidelines.md`）
- **テストケースは最低限かつ最小限**: 基本となるケースは抑えつつ、過度なテストは避ける（全ての条件分岐や組み合わせを網羅する必要はない）
- **既存パターンを尊重**: 同じディレクトリ内の他の spec ファイルのスタイルに合わせる
- **テスト実行は必須**: 必ず `docker compose exec api rspec` で動作確認すること
- ** 1 it 1 expect**: 一つのexpectにつき一つのitを原則とする
- rubocopの指摘を回避するために、意味のない関数化やメソッド分割をしない。必要があれば `rubocop:disable` コメントを使用しても良い
- expectで対象になるテストデータを作成する場合は let! で、対象範囲外になるテストデータを作成する場合は before で作成する
  - beforeで作成したテストデータについて、テスト対象内か対象外かコメントで残す

## Rspec 作成フロー

1. **コード分析**
   - 現在のブランチの変更差分のファイル（Model/Mutation/Resolver/Job/Lib など）を読み込み
   - テスト対象のメソッド・クラス・機能を詳細に分析
   - 既存の factory 定義を確認（src/api/spec/factories/）

2. **テスト設計**
   - testing-guidelines.md の方針に従ってテストケースを設計
   - 正常系・異常系・エッジケース等の観点でテストケースを洗い出す
   - 日本語で context/it を記述

3. **テスト実装**
   - プロジェクト固有パターンに従って RSpec コードを生成
   - 既存テストと同じスタイル・構造を維持

4. **Rspecチェックリスト**
   - テストコードがプロジェクトのルールに沿っているか、rspecチェックリストに基づいて確認
   - チェックリストに違反している場合は修正

5. **テスト実行・検証**
   - `docker compose exec api rspec` でテスト実行
   - エラー時は原因分析し、最大 2 回まで修正を試みる
   - rubocop 違反があれば修正（必要に応じて disable コメント）

## Rspecチェックリスト

- [ ] context/it は日本語で記述されていること
- [ ] 1 つの it ブロックに 1 つの expectであること
  - 複数の属性や値をまとめてテストしたい場合は `have_attributes` や `include` を使用。それが難しい場合は `aggregate_failures` を使用
- [ ] subjectを使用していないこと
- [ ] インスタンス変数は使用していないこと
- [ ] `described_class.last` や `ModelName.last` を使用していないこと
  - expect対象となるデータが必要な場合は、作成時に指定したパラメータで`find_by`で取得する
- [ ] 日時はiso8601形式で指定されていること（例: 2024-01-10T08:00:00Z）


### テストTips

- GlobalIDの指定方法
  - Base64エンコード前: `company.to_global_id.to_s`
  - Base64エンコード後: `company.to_gid_param`
- let!/before の使い分け
  - `let!`: テスト対象データ（必ず DB 保存が必要なもの）
  - `before`: 事前データや設定（複数テストで共通のもの）
- RuboCop RSpec の修正が困難な場合、対象範囲を`# rubocop:disable RSpec/ExampleLength` 〜 `# rubocop:enable RSpec/ExampleLength` のコメントで囲う
