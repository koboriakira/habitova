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

## 次のステップ

1. **Xcodeのインストール** - App Storeから最新版をインストール
2. **プロジェクト構造の作成** - 必要なディレクトリとファイルを作成
3. **Xcodeプロジェクトの作成** - iOS Appプロジェクトを作成
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
