# CircuitCanvas C1 / S1 修正後再テスト（2026-09-21）

## 対象

- 修正コミット: `27b8f09 Fix inspector deletion handling`
- 環境: iPad Pro 11-inch (M5) / iOS 26.5 シミュレーター

## 修正内容

- C1: インスペクタの編集Bindingを配列添字ではなくIDベースに変更し、付箋削除後の配列外アクセスを防止した。
- S1: シンボル削除時、そのシンボルのピンへ接続している配線を同時に削除するようにした。

## 再テスト結果

`xcodebuild test-without-building` で以下2件を実行し、成功した。

| UIテスト | 結果 | 確認内容 |
|---|---|---|
| `testDeletingNoteDoesNotCrash()` | 成功 | 付箋削除後、クラッシュせず概要表示へ戻ること |
| `testDeletingSymbolRemovesAttachedWires()` | 成功 | Temperature削除後、シンボルが消え、配線数が3本から2本になること |

補足: テストターゲットを含む `build-for-testing` も成功した。
