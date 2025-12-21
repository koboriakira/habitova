# Habitova

習慣形成AI アシスタントアプリ - ユーザーの理想の生活と実際の行動の乖離を継続的に検出・調整する秘書型習慣ナビゲーションシステム。

## 概要

Habitovaは、ユーザーの日常的な行動報告からAIが習慣の実行状況を分析し、個人に最適化された習慣形成をサポートするiOSアプリです。

### 主な機能

- **実行モード**: 日々の習慣実行をチャットで報告・分析
- **オンボーディングモード**: 習慣の詳細化と最適化
- **レポートモード**: 習慣実行状況の可視化と分析

## 技術スタック

- **フレームワーク**: SwiftUI + SwiftData
- **最小iOS**: 17.0+
- **アーキテクチャ**: MVVM (TCA対応準備済み)
- **API**: Claude AI (Anthropic)
- **データ**: SwiftData (ローカルストレージ)

## プロジェクト構造

```
habitova/
├── Habitova/                    # iOS SwiftUIプロジェクト
│   ├── Habitova.xcodeproj      # Xcodeプロジェクトファイル
│   ├── Habitova/               # アプリソースコード
│   │   ├── Models/             # SwiftDataモデル
│   │   ├── Services/           # APIサービス
│   │   ├── ViewModels/         # ビューモデル
│   │   ├── Features/           # TCA機能 (準備中)
│   │   └── MockData/           # テストデータ
│   ├── HabitovaTests/         # ユニットテスト
│   └── HabitovaUITests/       # UIテスト
├── prd/                       # プロダクト要求仕様書
│   ├── PROJECT_SUMMARY.md     # プロジェクト全体サマリー
│   ├── execution_mode_implementation_spec.md
│   └── habit_assistant_spec.md
└── docs/
    └── setup.md               # 開発環境セットアップ
```

## セットアップ

### 必要な環境

- Xcode 15.0+
- iOS 17.0+ シミュレーター
- macOS 14.0+

### インストール手順

1. **リポジトリのクローン**
   ```bash
   git clone <repository-url>
   cd habitova
   ```

2. **Xcodeでプロジェクトを開く**
   ```bash
   open Habitova/Habitova.xcodeproj
   ```

3. **Claude API キーの設定 (オプション)**
   ```bash
   export CLAUDE_API_KEY="your_api_key_here"
   ```
   ※ API キーが設定されていない場合、モックレスポンスで動作します

## ビルド・実行

### コマンドライン

```bash
# プロジェクトディレクトリに移動
cd /Users/a_kobori/git/habitova/Habitova

# iOSシミュレーター向けビルド
xcodebuild -project Habitova.xcodeproj -scheme Habitova -sdk iphonesimulator build

# 実機向けビルド
xcodebuild -project Habitova.xcodeproj -scheme Habitova -sdk iphoneos build

# クリーンビルド
xcodebuild clean -project Habitova.xcodeproj -scheme Habitova

# テスト実行
xcodebuild test -project Habitova.xcodeproj -scheme Habitova -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Xcode

1. `Habitova.xcodeproj` を開く
2. シミュレーターまたは実機を選択
3. `⌘ + R` でビルド・実行

## 開発状況

### 完了済み

- ✅ SwiftData モデル設計・実装
- ✅ 基本チャット UI
- ✅ Claude API サービス (URLSession版)
- ✅ モックデータシステム
- ✅ Swift 6 並行性対応

### 進行中・予定

- 🚧 TCA アーキテクチャ移行 (パッケージ準備済み)
- 🚧 Alamofire 統合
- ⏳ 習慣分析ロジック
- ⏳ レポート機能
- ⏳ オンボーディングフロー

## 使用技術・ライブラリ

- **SwiftUI**: UIフレームワーク
- **SwiftData**: データ永続化
- **URLSession**: HTTP通信 (現在の実装)
- **Combine**: リアクティブプログラミング
- **The Composable Architecture (TCA)**: 状態管理 (準備中)
- **Alamofire**: HTTP通信ライブラリ (準備中)

## API仕様

Claude APIを使用して、ユーザーの習慣報告を分析し、以下の情報を抽出します：

- 実行された習慣の特定
- チェーン整合性の確認
- プロアクティブな質問の生成
- 励ましのメッセージ

## トラブルシューティング

### ビルドエラー

1. **Alamofire リンクエラー**
   - 現在の実装はURLSessionを使用しており、Alamofireの依存関係を削除できます
   - または、プロジェクトのクリーンビルドを実行してください

2. **Swift並行性エラー**
   - すべてのモデルがSendableプロトコルに対応済みです
   - MainActor分離の問題は解決済みです

3. **Missing API Key**
   - API キーが未設定の場合、モックレスポンスで動作します
   - 実際のClaude APIを使用する場合は環境変数を設定してください

## ライセンス

このプロジェクトは開発中です。ライセンスについては後日決定予定です。

## 貢献

現在は個人開発プロジェクトです。

---

詳細な実装仕様については `prd/` ディレクトリ内の文書を参照してください。