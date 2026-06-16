---
description: 'Record videos of website usage using Playwright MCP or Playwright Core. Includes handling dialogs, scrolling, video compression, and common automation patterns. Use when users want to capture screen recordings, create demo videos, document UI/UX flows, or record testing sessions. Triggers: "録画して", "動画撮って", "screen recording", "record video", "capture website usage", "confirm dialog", "playwright video"'
metadata:
    github-path: dot_agents/skills/browser-video-record
    github-ref: refs/heads/main
    github-repo: https://github.com/okdyy75/dotfiles
    github-tree-sha: 03efd236108ac2619c67115fd151c51b2720852f
name: browser-video-record
---
# Browser Video Recording with Playwright

Webアプリケーションの操作を動画として記録するためのスキル。Playwright MCPとPlaywright Coreの両方に対応。

## 2つの録画方法

| 方法 | 特徴 | 用途 |
|------|------|------|
| **Playwright MCP** | ツール呼び出しで簡単録画 | 短いデモ、単純な操作 |
| **Playwright Core** | JavaScriptで細かく制御 | 複雑なCRUD操作、confirmダイアログ処理 |

---

## 方法1: Playwright MCP（推奨：単純な操作）

### Prerequisites

```bash
npx @playwright/mcp@latest --caps=devtools
```

### 基本的な録画フロー

```json
// 1. 録画開始
{
  "tool": "browser_start_video",
  "arguments": {
    "filename": "demo.webm",
    "size": { "width": 1280, "height": 720 }
  }
}

// 2. 操作を実行
{ "tool": "browser_click", "element": "保存ボタン" }
{ "tool": "browser_wait", "time": 2000 }

// 3. 録画停止
{ "tool": "browser_stop_video" }
```

### Chapter Marker（区切り表示）

```json
{
  "tool": "browser_video_chapter",
  "arguments": {
    "title": "ステップ1: ログイン",
    "description": "ユーザーがログイン",
    "duration": 2000
  }
}
```

---

## 方法2: Playwright Core（推奨：複雑な操作）

### 完全CRUD録画スクリプト

```javascript
const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    recordVideo: {
      dir: './videos',
      size: { width: 1280, height: 720 }
    }
  });

  const page = await context.newPage();

  // ⚠️ 重要: confirmダイアログを自動処理
  page.on('dialog', async dialog => {
    console.log(`Dialog: ${dialog.message()}`);
    await dialog.accept();
  });

  try {
    // === CREATE ===
    await page.goto('http://localhost:3000', { waitUntil: 'networkidle' });
    await page.waitForTimeout(3000);

    await page.click('button:has-text("新規作成")');
    await page.waitForTimeout(3000);

    await page.fill('input[type="text"]', 'テストアイテム');
    await page.click('button:has-text("保存")');
    await page.waitForTimeout(4000);

    // === UPDATE ===
    await page.click('button[title="編集"]');
    await page.waitForTimeout(3000);

    await page.fill('input[type="text"]', 'テストアイテム（編集済み）');
    await page.click('button:has-text("保存")');
    await page.waitForTimeout(4000);

    // === DELETE ===
    await page.click('button[title="編集"]');
    await page.waitForTimeout(3000);

    // 削除ボタンをスクロールしてクリック
    const deleteBtn = page.locator('button:has-text("削除")').first();
    await deleteBtn.scrollIntoViewIfNeeded();
    await deleteBtn.click();

    // confirmダイアログが表示され自動的にOKされる
    await page.waitForTimeout(4000);

    // 0件を確認
    await page.reload({ waitUntil: 'networkidle' });
    await page.waitForTimeout(3000);

  } finally {
    await context.close(); // 動画が保存される
    await browser.close();
  }
})();
```

---

## 重要テクニック

### 1. Confirm Dialog の自動処理（必須）

削除操作等で `window.confirm()` が表示される場合：

```javascript
// ページ作成直後に設定
page.on('dialog', async dialog => {
  if (dialog.type() === 'confirm') {
    await dialog.accept(); // OKをクリック
    // await dialog.dismiss(); // キャンセルをクリック
  }
});
```

**なぜ必要か**: confirmダイアログは自動的には閉じない。ハンドラを設定しないと処理が永遠にブロックされる。

### 2. 画面外要素のクリック

モーダル下部の削除ボタン等：

```javascript
const btn = page.locator('button:has-text("削除")').first();
await btn.scrollIntoViewIfNeeded(); // スクロールして表示
await btn.click();
```

### 3. 適切な待機時間（SPA対策）

| 操作 | 推奨待機時間 |
|------|-------------|
| ページ遷移後 | `waitUntil: 'networkidle'` + 2-3秒 |
| モーダル表示後 | 3-4秒 |
| 保存処理後 | 4-5秒 |
| 削除処理後 | 4-5秒 |

```javascript
await page.click('button:has-text("保存")');
await page.waitForTimeout(5000); // 処理完了を待つ
await page.reload({ waitUntil: 'networkidle' }); // 反映確認
```

---

## 動画の圧縮（ffmpeg）

WebM → MP4変換（Discord用に最適化）:

```bash
ffmpeg -i input.webm \
  -c:v libx264 \
  -preset fast \
  -crf 28 \
  -c:a aac \
  -b:a 96k \
  -movflags +faststart \
  output.mp4
```

パラメータ:
- `-crf 28`: 品質（17-28、低いほど高品質）
- `-b:a 96k`: 音声ビットレート
- `-movflags +faststart`: ストリーミング最適化

### 2倍速版を作る（playwright-mcp で長くなりがちな動画の短縮）

```bash
ffmpeg -i input.mp4 -filter:v "setpts=0.5*PTS" -an output-2x.mp4
```

- `setpts=0.5*PTS`: 再生速度 2倍
- `-an`: 音声削除（playwright-mcp の動画は基本無音）

---

## ⚠️ playwright-mcp のレイテンシ問題

playwright-mcp 経由のツール呼び出しは **1 回あたり 2〜5 秒** のラウンドトリップがかかる。録画中も含めて静止時間として動画に映る。

### 観測値（6 ステップ CRUD で計測）

| 手法 | 動画長 |
|---|---|
| `browser_snapshot` を毎ステップ取って ref を探索 | 約 7〜8 分 |
| `browser_evaluate` でセレクタ／クリック処理をバッチ化 | 約 5〜6 分 |
| ffmpeg で 2倍速にした版 | 約 3 分 |

### 短縮テクニック

1. **`browser_snapshot` を呼ばない**。代わりに `browser_evaluate` で必要な情報を 1 回でまとめて取得:
   ```javascript
   () => Array.from(document.querySelectorAll('[role="dialog"] label'))
     .map(l => ({ text: l.textContent.trim(), forId: l.getAttribute('for') }));
   ```
2. **クリック対象は CSS セレクタ（`#id` / `button >> text=...`）で `browser_click` する**。`ref=eXXX` は snapshot 依存で毎回取り直しが必要。
3. **複数の DOM 操作（テキスト入力 + ボタンクリック）は 1 回の evaluate にまとめる**。
4. **`browser_wait_for time=` は最小限**。3〜5 秒待ちが 6 回入ると 20 秒以上動画が伸びる。サーバ応答後の DOM 反映を待ちたい場合は次の evaluate でポーリングする手もある。
5. それでも長い場合は `ffmpeg ... setpts=0.5*PTS` で 2 倍速にする。

---

## React 制御コンポーネント（MUI 含む）の DOM 操作

`element.click()` や直接代入だけだと React の state が更新されないケースがある。

### controlled input / textarea の値設定

```javascript
const setVal = (el, v) => {
  const proto = el.tagName === 'TEXTAREA'
    ? window.HTMLTextAreaElement.prototype
    : window.HTMLInputElement.prototype;
  Object.getOwnPropertyDescriptor(proto, 'value').set.call(el, v);
  el.dispatchEvent(new Event('input', { bubbles: true }));
  el.dispatchEvent(new Event('change', { bubbles: true }));
  el.dispatchEvent(new Event('blur', { bubbles: true }));
};
```

### MUI Select を開く

```javascript
// .click() だけだと開かない。mousedown まで dispatch する
const sel = formControl.querySelector('.MuiSelect-select');
sel.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, button: 0 }));
sel.dispatchEvent(new MouseEvent('mouseup', { bubbles: true, button: 0 }));
sel.click();
// 開いた後、別 evaluate で role=option を .click() で選択する
```

### MUI Autocomplete を開く

入力 input の id を取得して `browser_click #<id>` で開く（mousedown 等が必要なため evaluate の `.click()` では開かないケースがある）。option の選択は evaluate の `.click()` で可。

### モーダル内の要素特定

複数モーダルが重なる可能性があるので必ず `document.querySelector('[role="dialog"]')` を起点に探索。可視性は `el.offsetParent !== null` でフィルタ。

```javascript
const dialog = document.querySelector('[role="dialog"]');
const dt = Array.from(dialog.querySelectorAll('input[placeholder="YYYY-MM-DD hh:mm"]'))
  .find(i => i.offsetParent !== null);
```

### snackbar が画面外に出てしまう

`browser_resize` で viewport を 1400×1000 にしても、`window.innerWidth/innerHeight` は実装上 1750×1250 などになることがある。MUI Snackbar が録画枠外に位置するケースがあるので、エラー確認は `browser_console_messages level=error` で取るのが確実。

---

## セレクタのベストプラクティス

### テキストベース

```javascript
await page.click('button:has-text("保存する")');
await page.locator('button:has-text("編集")').first().click();
```

### 属性ベース

```javascript
await page.click('button[title="編集"]');
await page.click('[data-testid="submit"]');
```

### チェーン

```javascript
const card = page.locator('.card').filter({ hasText: 'カフェ' }).first();
await card.locator('button[title="編集"]').click();
```

---

## トラブルシューティング

### "browser_start_video tool not found"
**原因**: MCPサーバーが `--caps=devtools` なしで起動
**解決**: `npx @playwright/mcp@latest --caps=devtools`

### 削除が実行されない
**原因**: confirmダイアログがブロック
**解決**: `page.on('dialog', async d => await d.accept())` を設定

### 要素が見つからない
**原因**: 要素が画面外またはまだレンダリングされていない
**解決**: `scrollIntoViewIfNeeded()` または待機時間を長く

### 動画がカクカクする
**原因**: 操作間の待機時間が短すぎる
**解決**: アクション間に 1000-2000ms の待機を追加

---

## デバッグテクニック

### コンソールログ監視

```javascript
page.on('console', msg => {
  if (msg.type() === 'error') console.log(`Error: ${msg.text()}`);
});
```

### スクリーンショット取得

```javascript
try {
  await page.click('button');
} catch (error) {
  await page.screenshot({ path: 'error.png', fullPage: true });
  throw error;
}
```
