---
name: browser-video-record
description: Record videos of website usage using Playwright MCP or Playwright Core. Includes handling dialogs, scrolling, video compression, and common automation patterns. Use when users want to capture screen recordings, create demo videos, document UI/UX flows, or record testing sessions. Triggers: "録画して", "動画撮って", "screen recording", "record video", "capture website usage", "confirm dialog", "playwright video"
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
