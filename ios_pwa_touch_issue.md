# iOS PWA タッチ反応問題の解決方法

## 問題の概要

**現象**: iPhone 15 Pro / Pro Max（iOS 17系）で PWA をホーム画面から起動した際、起動直後はタップ系イベントが全く反応せず、スワイプ・ピンチなどの連続ジェスチャーのみが動作する。一度「戻る」ジェスチャーを行うと、以降はすべてのタッチ操作が正常に動作するようになる。

**影響**: iPhone SE2 などの旧機種では発生しない。iPhone 15 Pro 系でのみ再現する。

## 根本原因

iOS 17 で追加された「Cross-document View Transitions」機能の WebKit バグ。

- PWA 起動時に `::view-transition-new(root)` という全画面の透明レイヤーが生成される
- このレイヤーが `pointer-events: auto` のまま残留することがある
- 残留中はタップ系イベントがすべて吸収され、下層の Flutter / JavaScript に届かない
- 「戻る」ジェスチャーでページが再描画されると、問題のレイヤーが破棄されるため正常動作する

**WebKit バグ**: [Bug 280703 / rdar://139591731](https://bugs.webkit.org/show_bug.cgi?id=280703)
- 修正パッチ 282105@main が WebKit に 2024-08-11 にコミット済み
- iOS 17.5 / iOS 18 β では解消確認済み
- 現行 17.4.1 以前では未修正

## 解決方法

### 1. View-Transition を無効化（推奨）

`web/index.html` の `<head>` セクションに以下を追加：

```html
<style>
  /* View-Transition 自体を作らせない */
  @view-transition { navigation: none; }

  /* 万一残留した場合に備えてポインタも殺す */
  html::view-transition-old(root),
  html::view-transition-new(root){
    pointer-events:none !important;
  }
</style>
```

### 2. キャッシュ更新の重要性

PWA は Service Worker が `index.html` をキャッシュするため、ファイルを編集しても古いバージョンが使われ続ける場合がある。

**対処方法**:
1. PWA をアンインストール → 再度ホーム画面に追加（最も簡単）
2. または Service Worker の `revision` を変更して `flutter build web` → 再デプロイ

### 3. 確認方法

Safari で直接 `https://<app>/index.html?ts=NOW` を開き、ページソースに追加した `<style>` が含まれているか確認する。

## 代替解決策

### JavaScript による除去

```javascript
window.addEventListener('pageshow', ()=>{
  document.querySelectorAll('[pseudo="-webkit-view-transition"]')
          .forEach(n=>n.remove());
});
```

### CSS のみでの対処

```css
html::view-transition-old(root),
html::view-transition-new(root){
  display:none !important;      /* レイヤーを作らせない */
  pointer-events:none !important;
}
```

## 今後の対応

- iOS 17.5 以降では OS 側で修正される予定
- 修正後は追加した CSS を削除することで、本来の View-Transition 機能を再び利用可能

## 参考リンク

- [WebKit Bug 280703](https://bugs.webkit.org/show_bug.cgi?id=280703)
- [Apple Developer Forums - iOS 18.2 beta broke web views](https://developer.apple.com/forums/thread/768717)
- [Flutter Issue #145742](https://github.com/flutter/flutter/issues/145742)

---

**注意**: この問題は iPhone 15 Pro 系でのみ発生する WebKit の既知バグです。Flutter アプリケーション側のコードに問題があるわけではありません。 