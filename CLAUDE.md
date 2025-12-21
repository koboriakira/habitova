# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

習慣形成AI アシスタントアプリ「Habitova」 - ユーザーの理想の生活と実際の行動の乖離を継続的に検出・調整する秘書型習慣ナビゲーションシステム。

## 開発環境

### iOS アプリ
- **フレームワーク**: SwiftUI + SwiftData
- **最小iOS**: 17.0+
- **テスティング**: Swift Testing (新しいテスティングフレームワーク)

### プロジェクト構造
```
habitova/
├── Habitova/                    # iOS SwiftUIプロジェクト
│   ├── Habitova.xcodeproj      # Xcodeプロジェクトファイル
│   ├── Habitova/               # アプリソースコード
│   ├── HabitovaTests/         # ユニットテスト
│   └── HabitovaUITests/       # UIテスト
├── prd/                       # プロダクト要求仕様書 (重要)
│   ├── PROJECT_SUMMARY.md     # プロジェクト全体サマリー
│   ├── execution_mode_implementation_spec.md  # 実行モード実装仕様
│   └── habit_assistant_spec.md                # アプリ完全仕様書
└── docs/
    └── setup.md               # 開発環境セットアップ手順
```

## コマンド

### Xcodeプロジェクト操作
```bash
# プロジェクトを開く
open Habitova.xcodeproj

# コマンドラインでビルド
xcodebuild -project Habitova.xcodeproj -scheme Habitova build

# テスト実行
xcodebuild test -project Habitova.xcodeproj -scheme Habitova -destination 'platform=iOS Simulator,name=iPhone 15'

# クリーンビルド
xcodebuild clean -project Habitova.xcodeproj -scheme Habitova
```

## アーキテクチャ概要

### 3つのモード設計
1. **実行モード（日常利用）** - ユーザー報告受付 → リアルタイム推測判定 → シンプルなAI応答
2. **Onboardingモード（習慣詳細化）** - 質問リスト処理 → ユーザー対話的習慣最適化 → Interview更新
3. **レポートモード（進捗分析）** - 統計分析 → パターン抽出 → フィードバック生成

### 重要な設計概念
- **重要度システム**: `importance`（明示的）+ `importanceInferred`（推測）+ `hiddenParameters`（複数の隠れた属性）
- **チェーン整合性**: 期待される習慣の順序 vs 実際の報告順序を比較
- **タスク vs 習慣**: 繰り返し行動（習慣化候補）と単発イベントの区別
- **前提条件チェーン**: 物理的な準備習慣のサポート（例：ストレッチ前に机をどかす）

### モックデータ（開発用）
- テストユーザー: Akira（36歳、5歳の子ども）
- 定義済み習慣: 12個（朝7時起床、洗顔、コーヒー、ストレッチ等）
- 定義済みチェーン: 8個（朝のルーティン、夜のルーティン等）

## 実装フェーズ計画

### Phase 1: 実行モード（6週間） - 現在のフォーカス
- DBスキーマ（PostgreSQL + JSON サポート）
- NLP エンジン（Claude API統合）
- ExecutionInference エンジン
- メッセージ処理API
- シンプルなチャットUI

### Phase 2: Onboarding モード
- QueuedOnboardingQuestions 処理
- 動的質問生成
- Interview バージョン管理

### Phase 3: レポートモード  
- HabitReport 生成
- パターン分析
- AI フィードバック

## データモデル（重要）

### 主要エンティティ
- `Habit`: 習慣定義（name, targetFrequency, importance, hiddenParameters等）
- `HabitChain`: 習慣間の連鎖関係
- `HabitExecution`: 習慣実行ログ
- `Message`: 会話ログ
- `ExecutionInference`: AI推測ログ
- `QueuedOnboardingQuestions`: Onboarding質問キュー
- `Task`: 単発タスク

### SwiftData モデル
現在は `Item` モデルのみ実装済み。上記エンティティをSwiftDataモデルとして実装する必要がある。

## 開発時の重要な注意点

### NLP処理
- Claude APIを使用（精度重視）
- 習慣IDの抽出 + 実行タイプ判定（direct/partial/inferred）
- チェーン整合性チェックによるプロアクティブ質問生成

### UI/UX方針
- 実行モードはシンプル（短い質問のみ）
- 自動モード遷移しない（ユーザー混乱回避）
- 詳細情報は質問リストにキューイング

### テスト戦略
- モックユーザー（Akira）でのエンドツーエンドテスト
- チェーン整合性チェックの正常動作確認
- Onboardingキュー記録機能の検証

## API設計（将来のバックエンド）

```
POST /api/v1/messages      # メッセージ送信
GET /api/v1/habits/{id}/expected-chain  # チェーン整合性チェック
GET /api/v1/users/{id}/habits          # ユーザー習慣取得
```

## 技術スタック（完成時）

### バックエンド（将来）
- Python/Node.js + FastAPI/Express
- PostgreSQL（JSONサポート）
- Claude API

### フロントエンド（現在）  
- iOS: SwiftUI + SwiftData
- Web（将来）: React/Vue + Tailwind CSS