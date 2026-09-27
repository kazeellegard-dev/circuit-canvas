# タスク（第3弾 3B）: ブロックを汎用ブロック1種類にし、名称・アイコンを後から選べるようにする

前提: 3A（付箋・インスペクタ整理）の後に着手する。

## 要件

- ライブラリの「ブロック」カテゴリを、**「汎用ブロック」1 種類だけ**にする。既存の `DC/DC`・`MCU`・`CAN`・`センサー`・`汎用ブロック`（`SymbolKind` の `converter, mcu, can, sensor, block`）は、`block` 1 種類に統合する。他の 4 種類（と、それぞれの `icon`）は、削除する。
  - 初期データ（`24 V → 5 V`・`Main MCU`・`CAN`・`Temperature`）は、種類はすべて `block` になるが、**タイトルとアイコンは、今のまま**にする（見た目は変わらない）。
- 配置した直後の汎用ブロックは、タイトルが「汎用ブロック」、アイコンが `square.dashed`（今の既定と同じ）になる。
- **インスペクタで、名称とアイコンを、あとから編集できる。**
  - 名称は、今の `TextField("名称", ...)` のまま。
  - アイコンは、新しく「アイコン」の行を置き、タップすると、アイコンを選ぶ画面（シートか、インスペクタ内の折りたたみ）が開く。カテゴリ別のグリッドから選ぶ。
- アイコンの候補（下の一覧。数や種類は、実装時に増減してよい）:

```
基板・部品: cpu, memorychip, antenna.radiowaves.left.and.right, wifi, network,
           sensor.tag.radiowaves.forward, bolt.fill, bolt.batteryblock, speaker.wave.2.fill
通信・接続: arrow.left.and.right, arrow.triangle.branch, point.3.connected.trianglepath.dotted,
           cable.connector
筐体・機構: shippingbox, cube, gearshape.fill, fan.fill, thermometer
表示・操作: display, switch.2, slider.horizontal.3, lightbulb.fill
汎用図形:   square.dashed, circle.dashed, triangle, hexagon, diamond
```

- `SymbolItem`（または `SymbolKind`）に、アイコンを保持する場所を作る。回路記号（circuit）は、対象外（アイコンを持たない。今どおり `CircuitGlyph` を描く）。
- ライブラリの「汎用ブロック」の絵は、既定のアイコン（`square.dashed`）で表示する。

## 受け入れ条件

| # | 操作 → 期待する結果 | UIテスト化 |
|---|---|---|
| G1 | ライブラリの「ブロック」カテゴリに、「汎用ブロック」しかない。 | する |
| G2 | 汎用ブロックを配置すると、タイトル「汎用ブロック」・アイコン `square.dashed`。 | する |
| G3 | インスペクタの「アイコン」をタップし、候補から選ぶと、ブロックの表示アイコンが変わる。 | する |
| G4 | 初期データの 4 つのブロックは、タイトル・アイコンが変わらない（種類は `block` になるが、見た目は同じ）。 | する（既存テストの更新） |
| G5 | アイコンの選択画面は、カテゴリ別に見やすく並ぶ。ダークモードでも見える。 | QA が確認 |

## 仮定
- アイコン名は、SF Symbols の名前をそのまま使う（`Image(systemName:)`）。
- アイコンの選択は、配置後の編集のみ（配置時に選ぶ操作は、今回は用意しない。既定のアイコンで置いてから、インスペクタで変える）。
