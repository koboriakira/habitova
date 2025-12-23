# Habitova テストスイート概要

## 🧪 チェーントリガー統合テストについて

3連続習慣チェーン（起床→洗顔→コーヒー）の動作を確保するための包括的なテストスイートを実装しています。

### 📋 テスト分類

#### ✅ **有効なテスト（常時実行）**

1. **`testWakeupTriggersWashing`** - 起床→洗顔トリガーテスト
   - モックデータを使用
   - 実行時間: ~0.01秒
   - 検証内容: 起床報告後に洗顔トリガーメッセージが生成される

2. **`testWashingTriggersCoffee`** - 洗顔→コーヒートリガーテスト  
   - モックデータを使用
   - 実行時間: ~0.01秒
   - 検証内容: 洗顔報告後にコーヒートリガーメッセージが生成される

3. **`testThreeStepChainExecution`** - 3連続チェーン完全実行テスト
   - モックデータを使用
   - 実行時間: ~0.01秒
   - 検証内容: 起床→洗顔→コーヒーの連続チェーンが順次正しく動作する

4. **`testChainConsistencyCheck`** - チェーン整合性チェックテスト
   - モックデータを使用
   - 実行時間: ~0.01秒
   - 検証内容: スキップされた習慣の検出機能

5. **エラーハンドリングテスト群**
   - 空のデータベース処理
   - 不正なUUID処理
   - 破損したチェーンデータ処理
   - 大量データでのパフォーマンステスト

6. **複雑なチェーンテスト群**
   - 複数トリガー習慣チェーン
   - 分岐チェーン（一対多）
   - 合流チェーン（多対一）

#### ⏸️ **無効化されたテスト（手動実行のみ）**

以下のテストは実際のClaude APIを使用するため、`.disabled()` で無効化されています：

1. **`testClaudeAPIWakeupIntegration`** - 実際のAPI統合テスト（起床）
   - **無効化理由**: 本物のClaude APIを呼び出すため
   - **実行時間**: ~4秒
   - **検証内容**: 「起きました」→習慣認識→トリガー生成の完全フロー

2. **`testClaudeAPIWashingIntegration`** - 実際のAPI統合テスト（洗顔）
   - **無効化理由**: 本物のClaude APIを呼び出すため
   - **実行時間**: ~4秒
   - **検証内容**: 「洗顔しました」→習慣認識→トリガー生成の完全フロー

3. **`testEndToEndChatViewModelIntegration`** - エンドツーエンド統合テスト
   - **無効化理由**: SimpleChatViewModel経由でClaude APIを呼び出すため
   - **実行時間**: ~4-5秒
   - **検証内容**: UI→ViewModel→API→データベースの完全フロー

4. **`testRealAPIComplexInput`** - 自然言語複雑入力テスト
   - **無効化理由**: 本物のClaude APIで複雑な文章を解析するため
   - **検証内容**: 長文・複文の自然言語処理能力

5. **`testAPIResponseTime`** - APIレスポンス時間測定
   - **無効化理由**: 実際のAPIレスポンス時間を測定するため
   - **検証内容**: パフォーマンス基準（10秒以下）の確認

### 🔧 手動でAPIテストを実行する方法

```bash
# 1. Claude APIキーを設定
export CLAUDE_API_KEY="your_api_key_here"

# 2. 特定のAPIテストを実行（例：起床統合テスト）
xcodebuild test -project Habitova.xcodeproj -scheme Habitova \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  -only-testing HabitovaTests/ChainTriggerIntegrationTests/testClaudeAPIWakeupIntegration

# 3. すべてのAPIテストを実行
xcodebuild test -project Habitova.xcodeproj -scheme Habitova \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  -only-testing HabitovaTests/ChainTriggerAdvancedTests
```

### 📊 テスト実行時間の目安

| テスト分類 | 実行時間 | API使用 |
|------------|----------|---------|
| モックテスト | 0.01秒 | なし |
| 実際のAPIテスト | 4-5秒 | あり |
| パフォーマンステスト | 0.1-1秒 | なし |
| エラーハンドリングテスト | 0.01秒 | なし |

### 🎯 テストカバレッジ

- ✅ ChainTriggerService の全機能
- ✅ 3連続チェーンの動作保証
- ✅ エラーハンドリング
- ✅ パフォーマンス検証
- ✅ 複雑なチェーンパターン
- ✅ 実際のClaude API統合（手動）
- ✅ エンドツーエンド動作（手動）

### 📝 注意事項

1. **CI/CD環境**: 有効なテストのみが自動実行されます
2. **開発時**: 無効化されたテストを手動実行してAPI統合を確認してください
3. **APIキー**: 実際のAPIテストにはClaude APIキーが必要です
4. **コスト考慮**: 実際のAPIテストは使用量にカウントされます

### 🔄 今後の拡張予定

- [ ] モック精度向上（実際のAPIレスポンスとの一致度向上）
- [ ] より複雑な習慣チェーンパターンのテスト
- [ ] 並行実行時の動作テスト
- [ ] 長時間実行テスト（24時間サイクル）