# API秘匿情報管理戦略

## 概要
Claude API キーなどの秘匿情報を安全に管理するための戦略文書

## セキュリティレベル別アプローチ

### 1. 開発・テスト環境（現在の実装）
**手法**: 環境変数 + `.gitignore`されたローカル設定ファイル

**実装方法**:
```swift
// 環境変数から取得（現在の方法）
self.apiKey = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"] ?? ""

// または、ローカル設定ファイルから取得
self.apiKey = ConfigLoader.loadAPIKey()
```

**長所**: 
- シンプルで開発しやすい
- ソースコードにハードコーディングしない

**短所**: 
- アプリバンドルに含まれるリスク
- 静的解析で発見される可能性

### 2. 本番環境（推奨）
**手法**: バックエンド経由でのAPI呼び出し

**アーキテクチャ**:
```
iOS App → 自社バックエンド → Claude API
```

**長所**: 
- APIキーがクライアントに露出しない
- 使用量制限・課金管理が容易
- ログ・監査が可能

**短所**: 
- バックエンドの開発・運用が必要
- レスポンスの遅延

### 3. 高セキュリティ環境
**手法**: iOS Keychain + Certificate Pinning + 認証

**実装要素**:
- iOS Keychain Servicesでの暗号化保存
- SSL Certificate Pinning
- JWT認証トークンによるセッション管理
- API使用量監視

## 推奨実装計画

### Phase 1: 開発環境の整備（今回実装）
1. 設定ファイル分離
2. 環境別設定の管理
3. 開発者向けのセットアップ手順

### Phase 2: セキュア実装（将来）
1. バックエンドAPIの構築
2. 認証システムの実装
3. エラーハンドリングの強化

### Phase 3: プロダクション対応
1. 監視・ログシステム
2. レート制限の実装
3. セキュリティ監査

## 即時実装案

### 1. 設定ファイルアプローチ
```swift
// Config.swift
struct APIConfig {
    static let shared = APIConfig()
    
    private let config: [String: Any]
    
    private init() {
        guard let path = Bundle.main.path(forResource: "APIConfig", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            self.config = [:]
            return
        }
        self.config = dict
    }
    
    var claudeAPIKey: String {
        return config["CLAUDE_API_KEY"] as? String ?? ""
    }
    
    var baseURL: String {
        return config["BASE_URL"] as? String ?? "https://api.anthropic.com/v1/messages"
    }
}
```

### 2. 実行時キー入力アプローチ（デモ用）
```swift
// ユーザーが設定画面でAPIキーを入力
// Keychainに保存して再利用
```

## セキュリティ考慮事項

### ✅ 実装すべき対策
- [ ] ソースコードからAPIキーを完全除去
- [ ] Bundle検証による改ざん防止
- [ ] ネットワーク通信の暗号化
- [ ] エラーメッセージでの情報漏洩防止

### ❌ 避けるべき実装
- APIキーのハードコーディング
- 平文での設定ファイル保存
- UserDefaultsでの保存
- ログファイルへのキー出力

## 今回の実装方針
1. **短期**: 設定ファイル + Keychain の組み合わせ
2. **中期**: 設定画面での手動キー入力オプション
3. **長期**: バックエンド経由のAPI呼び出し

## 開発環境セットアップ手順

### .env ファイルを使った開発環境構築

**前提**: 開発時に `.env` ファイルを使ってAPIキーを管理し、ビルド時にアプリバンドルにコピーする方式

#### 1. 環境ファイルの準備
```bash
# プロジェクトルートに .env ファイルを作成
cp .env.template .env

# API キーを設定（実際のキーに置き換える）
echo "CLAUDE_API_KEY=sk-ant-your-actual-api-key-here" > .env
```

#### 2. .env ファイルをプロジェクトリソースとして追加（推奨方法）
1. **Xcodeプロジェクトを開く**
2. **ビルドスクリプトを無効化**（既に追加済みの場合）:
   - TARGETS > Habitova > Build Phases
   - Run Script のチェックボックスを外して無効化
3. **.env ファイルを直接追加**：
   - Finderで `.env` ファイルを選択
   - XcodeのProject Navigatorにドラッグ&ドロップ
   - ダイアログで以下を設定：
     - **"Copy items if needed"** をチェック ✅  
     - **"Add to target"** で "Habitova" をチェック ✅
     - "Create groups" を選択

**代替方法: ビルドスクリプト** (上級者向け)：
1. Build Phases → "+" → "Run Script" 追加
2. スクリプト内容: `"${SOURCE_ROOT}/copy-env.sh"`  
3. Compile Sourcesの前に配置

#### 3. 動作確認
```bash
# ビルドを実行
xcodebuild -project Habitova.xcodeproj -scheme Habitova build
```

ビルド成功時、以下のログが表示されます：
```
ビルドスクリプト: .env ファイルをコピー中...
.env ファイルが見つかりました。アプリバンドルにコピー中...
.env ファイルのコピーが完了しました。
コピーされた .env ファイルの内容（APIキーはマスク）:
CLAUDE_API_KEY=[MASKED]
```

#### 4. アプリでの確認方法
1. アプリを起動
2. 設定画面を開く
3. `.env` ファイルのAPIキーが初期値として表示される
4. チャット画面でメッセージを送信してClaude API接続を確認

### セキュリティ注意事項

#### ✅ 開発時のベストプラクティス
- `.env` ファイルは `.gitignore` に追加済み（コミット対象外）
- API キーはKeychainに暗号化保存される
- ログ出力時はAPIキーがマスクされる

#### ❌ 避けるべき行為
- `.env` ファイルのコミット
- API キーの画面スクリーンショット共有
- Slackなどでのクリアテキストでのキー共有

### トラブルシューティング

#### `.env ファイルが見つからないエラー`
```
EnvironmentLoader: .envファイルが見つかりません。ビルドスクリプトで開発環境の.envをコピーしてください。
```
**解決方法**:
1. プロジェクトルートに `.env` ファイルが存在するか確認
2. Xcodeのビルドスクリプトが正しく設定されているか確認
3. `copy-env.sh` に実行権限があるか確認: `chmod +x copy-env.sh`

#### APIキー認証エラー
```
API Error: Invalid API key
```
**解決方法**:
1. `.env` ファイル内のAPIキー形式確認（`sk-ant-` で始まる）
2. Anthropic Consoleで有効なAPIキーか確認
3. 設定画面でAPIキーの再入力と保存を実行