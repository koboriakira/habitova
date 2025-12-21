# 開発環境セットアップ

このドキュメントでは、AI Reminder iOSアプリの開発に必要な環境構築手順を説明します。

## 必要な開発ツール

### 1. Homebrew
パッケージ管理システム。macOSでの開発に必須です。

**確認コマンド:**
```bash
brew --version
```

**未インストールの場合:**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Xcode
iOS開発に必須の統合開発環境。

**確認コマンド:**
```bash
xcodebuild -version
```

**インストール手順:**
1. App Storeから「Xcode」を検索してインストール
2. インストール後、以下のコマンドでCommand Line Toolsを設定:
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### 3. Claude Code
AI支援開発ツール。

**確認コマンド:**
```bash
claude --version
```

**インストール済み:**
- ✅ Claude Code 1.0.31

**未インストールの場合:**
Claudeの公式サイトから最新版をダウンロードしてインストール。

## プロジェクト構造

```
smart-tasks-ios/
├── .gitignore
├── .claude/
│   └── context/
│       └── architecture.md
├── README.md
├── AIReminder/              # Xcodeプロジェクト（後で作成）
└── docs/
    └── setup.md
```

## Xcodeプロジェクトの作成

### 方法1: Xcode GUIから作成（推奨）

1. **Xcodeを起動**
   ```bash
   open -a Xcode
   ```

2. **新規プロジェクトの作成**
   - 「Create New Project」をクリック
   - 「iOS」タブを選択
   - 「App」テンプレートを選択 → Next

3. **プロジェクト設定**
   - **Product Name**: `Habitova`
   - **Team**: 個人のApple Developer Team（または None）
   - **Organization Identifier**: `com.koboriakira.habitova`（適宜変更）
   - **Bundle Identifier**: 自動生成される
   - **Interface**: `SwiftUI`
   - **Language**: `Swift`
   - **Storage**: `SwiftData`（推奨）
     - **SwiftData**: Swift言語ネイティブのデータ永続化フレームワーク（iOS 17+、推奨）
     - **Core Data**: 従来のデータ永続化フレームワーク
     - **None**: データ永続化なし（後から追加可能）
   - **Testing System**: `Swift Testing`（推奨、iOS 17+）
     - **Swift Testing**: 新しいテスティングフレームワーク（推奨）
     - **XCTest**: 従来のテスティングフレームワーク

4. **保存場所**
   - **Where**: `/Users/a_kobori/git/habitova/`
   - **Create Git repository**: ❌ チェックを外す（既にGitリポジトリ内のため）

5. **作成完了後の構造**
   ```
   habitova/
   ├── Habitova.xcodeproj      # Xcodeプロジェクトファイル
   ├── Habitova/
   │   ├── HabitovaApp.swift   # アプリエントリーポイント
   │   ├── ContentView.swift     # メインビュー
   │   ├── Assets.xcassets       # 画像・アイコン
   │   └── Preview Content/
   └── HabitovaTests  /          # テストファイル
   ```

### 方法2: コマンドラインから作成

XcodeプロジェクトはGUIから作成することを強く推奨しますが、テンプレートを手動で作成することも可能です。

## 次のステップ

1. ✅ **Xcodeのインストール** - 完了
2. ✅ **プロジェクト構造の作成** - 完了
3. **Xcodeプロジェクトの作成** - 上記手順で実施
4. **開発開始** - 基本的なアプリ構造の実装

## トラブルシューティング

### xcodebuild エラーが出る場合
```bash
# 現在のDeveloper Directoryを確認
xcode-select -p

# Xcodeインストール後、正しいパスに設定
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# 再度確認
xcodebuild -version
```
