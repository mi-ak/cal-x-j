---
title: cal-x-j
author: "mi-ak"
license: MIT
version: 0.1.0
description: "XTEINK X4 用 日本向けカレンダープラグイン"
---

<p align="right">
  <a href="./README.md">🇺🇸 English</a>
</p>

# cal-x-j

`cal-x-j`（カル・エックス・ジェー）は、XTEINK X4（カスタムファームウェア: crosspoint-reader-lua）向けに作成した、日本向けカレンダーLuaプラグインです。

名前の `cal` は calendar、`x` は XTEINK X4、`j` は Japanese を意味しています。

e-inkデバイス上で軽量かつシンプルに動作し、年・月表示が可能です。（日本の祝日対応あり）

## Preview

### Month View
![month](./docs/month.jpg)

### Year View
![year](./docs/year.jpg)

## Concept

`cal-x-j` は、移動時にスーツの胸ポケットに入れたり、デスクでバッテリーを気にせず置きっぱなしにできるミニカレンダーを実現するために作成しました。

## 対象ユーザー

- XTEINK X4 を使用している方
- e-inkデバイスで軽量なカレンダーを求めている方
- crosspoint-reader-lua 環境を構築済みの方

## 機能

- 📅 月表示 / 年表示の切り替え(週頭切替月,日,土のパターンを用意)
- 🇯🇵 日本の祝日を表示
- 🗂 年表示で四半期と月の祝日数を可視化（設定で切替可能）
- 🔢 月表示で週番号表示（設定で切替可能）
- 💾 表示した状態は自動保存
- ⚡ 軽量 Lua 実装（低リソース環境向け）

## インストール

0. crosspoint-reader-lua を XTEINK X4 にインストールし、日本語フォントを配置して日本語環境を構築します。
   - 公式: https://github.com/ideo2004-afk/crosspoint-reader-lua

1. このcal-x-jリポジトリをクローンまたはダウンロードします。
2. 以下のように配置します：

SDカードの構成例:

```
/sdcard/
 ├─ plugins/
 │   └─ cal-x-j/
 │       ├─ main.lua
 │       └─ settings.txt
```

3. XTEINK X4 を起動し、プラグインを有効化します。

## 日本語フォント対応

`cal-x-j` は XTEINK X4（カスタムファームウェア: crosspoint-reader-lua）で動作するLuaプラグインです。カスタムの CJK フォントを使用する場合は、公式のフォント変換ツールで `.bin` 形式に変換し、SD カードの `/fonts/` に配置してください。

> 依存: https://github.com/ideo2004-afk/crosspoint-reader-lua

### フォント変換（公式ツール）

- 公式フォント変換スクリプト: `tools/crosspoint-reader-lua/CJK-font-converter/convert_font.py`
- 変換例:

```sh
python3 /path/to/CJK-font-converter/convert_font.py  --font ./16_NotoSansJP/NotoSansJP-Medium.otf --size 18 --output /path/to/sdcard/fonts/NotoSansJP-Medium_18_18x27.bin
```
### フォント配置

1. 生成した `.bin` ファイルを SD カードの `/fonts/` フォルダにコピーします。
2. XTEINK X4 のフォント管理から外部フォントを選択できる環境であれば、生成したフォントが利用可能になります。

> 例: `/sdcard/fonts/NotoSansJP-Medium_18_18x27.bin`

## 操作方法

- ← / → : 月を切り替え
- ↑ : 週開始曜日を切り替え
- ↓ : ヒント表示 ON/OFF
- OK : 年表示 / 月表示 切替
- BACK : 終了


## 設定

`/path/to/sdcard/plugins/cal-x-j/settings.txt` に以下の設定を保存します。

- showHints (bool) : ヒント表示
- showQuarter (bool) : 年ビューで四半期ラベル表示
- showHolidayCount (bool) : 年ビューで祝日数表示
- showWeekNumber (bool) : 月ビューで週番号表示
- startDow (int) : 週開始曜日（0=日曜, 1=月曜）
- viewMode (string) : `month` または `year`
- viewYear (int) : 表示年
- viewMonth (int) : 表示月
- selMonth (int) : 年ビューで選択中の月

### settings.txt の例
```txt
showHints=true
showQuarter=true
showHolidayCount=false
showWeekNumber=true
startDow=0
viewMode=month
viewYear=2026
viewMonth=4
selMonth=4
```

## 開発

### Requirements

- Lua 5.3+

## ファイル構成

- `main.lua` - プラグイン本体
- `LICENSE` - MIT ライセンス

## ライセンス

本プロジェクトは MIT License の下で公開されています。詳細は LICENSE ファイルを参照してください。

## 作者

[`mi-ak`](https://github.com/mi-ak)
