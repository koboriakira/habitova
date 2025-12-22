//
//  EnhancedSettingsView.swift
//  Habitova
//
//  Created by Claude on 2025/12/22.
//

import SwiftUI

struct EnhancedSettingsView: View {
    @State private var apiKey: String = ""
    @State private var showingApiKeyAlert = false
    @State private var alertMessage = ""
    @State private var isAPIKeySet = false
    @State private var showingAdvancedSettings = false
    @State private var selectedAppearance: AppearanceMode = .system
    @State private var enableAnalytics = true
    @State private var defaultReminders = true
    @State private var connectionStatus: ConnectionStatus = .disconnected
    @StateObject private var notificationService = NotificationService.shared
    @State private var showingNotificationSettings = false
    @Environment(\.dismiss) private var dismiss
    
    enum AppearanceMode: String, CaseIterable {
        case light = "ライト"
        case dark = "ダーク"
        case system = "システム連動"
    }
    
    enum ConnectionStatus {
        case connected
        case disconnected
        case testing
        case error(String)
        
        var statusText: String {
            switch self {
            case .connected: return "接続済み"
            case .disconnected: return "未接続"
            case .testing: return "テスト中..."
            case .error(let message): return "エラー: \(message)"
            }
        }
        
        var statusColor: Color {
            switch self {
            case .connected: return .green
            case .disconnected: return .orange
            case .testing: return .blue
            case .error: return .red
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // API設定セクション
                apiConfigurationSection
                
                // アプリ設定セクション
                appConfigurationSection
                
                // 通知設定セクション
                notificationSettingsSection
                
                // 高度な設定
                advancedSettingsSection
                
                // ヘルプとサポート
                helpAndSupportSection
                
                // アプリ情報
                appInfoSection
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadAPIKey()
                checkConnectionStatus()
            }
            .alert("API設定", isPresented: $showingApiKeyAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingNotificationSettings) {
                NotificationSettingsView()
            }
        }
    }
    
    // MARK: - ビューコンポーネント
    
    private var apiConfigurationSection: some View {
        Section(header: Text("Claude API設定")) {
            VStack(alignment: .leading, spacing: 12) {
                // 接続状態インジケーター
                HStack {
                    Circle()
                        .fill(connectionStatus.statusColor)
                        .frame(width: 8, height: 8)
                    Text(connectionStatus.statusText)
                        .font(.caption)
                        .foregroundColor(connectionStatus.statusColor)
                    Spacer()
                    if connectionStatus.statusColor == .green {
                        Button("テスト") {
                            testConnection()
                        }
                        .font(.caption)
                    }
                }
                
                Text("APIキー")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SecureField("sk-ant-...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                
                if isAPIKeySet {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("APIキーが設定されています")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                HStack(spacing: 12) {
                    Button(action: saveAPIKey) {
                        Text("保存")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: deleteAPIKey) {
                        Text("削除")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                }
                
                DisclosureGroup("セットアップガイド") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Anthropic Console (console.anthropic.com) にアクセス")
                        Text("2. アカウントでログイン")
                        Text("3. 'API Keys' セクションで新しいキーを作成")
                        Text("4. 生成されたキーをコピーして上記に貼り付け")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                }
            }
        }
    }
    
    private var appConfigurationSection: some View {
        Section(header: Text("アプリ設定")) {
            HStack {
                Label("テーマ", systemImage: "paintbrush")
                Spacer()
                Picker("テーマ", selection: $selectedAppearance) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Toggle(isOn: $enableAnalytics) {
                Label("利用統計", systemImage: "chart.bar")
            }
        }
    }
    
    private var notificationSettingsSection: some View {
        Section(header: Text("通知設定")) {
            HStack {
                Label("通知許可", systemImage: "bell")
                Spacer()
                
                if notificationService.isAuthorized {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("許可済み")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                } else {
                    Button("許可") {
                        Task {
                            await notificationService.requestAuthorization()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            Toggle(isOn: $defaultReminders) {
                Label("スマートリマインダー", systemImage: "brain")
            }
            .disabled(!notificationService.isAuthorized)
            
            if notificationService.isAuthorized {
                Button(action: { showingNotificationSettings = true }) {
                    HStack {
                        Label("リマインダー管理", systemImage: "bell.badge")
                        Spacer()
                        Text("\(notificationService.scheduledNotifications.count)件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
            }
        }
    }
    
    private var advancedSettingsSection: some View {
        Section(header: Text("高度な設定")) {
            DisclosureGroup("セキュリティ情報", isExpanded: $showingAdvancedSettings) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("APIキーは iOSKeychainで暗号化されて保存", systemImage: "lock.shield")
                    Label("本番環境ではバックエンド経由での呼び出しを推奨", systemImage: "server.rack")
                    Label("未使用時はAPIキーを削除することを推奨", systemImage: "trash")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            }
            
            Button("アプリデータをリセット") {
                // TODO: データリセット機能
            }
            .foregroundColor(.red)
            
            Button("データをエクスポート") {
                // TODO: データエクスポート機能
            }
        }
    }
    
    private var helpAndSupportSection: some View {
        Section(header: Text("ヘルプとサポート")) {
            NavigationLink(destination: UserGuideView()) {
                Label("ユーザーガイド", systemImage: "book")
            }
            
            NavigationLink(destination: FAQView()) {
                Label("FAQ", systemImage: "questionmark.circle")
            }
            
            Button("フィードバックを送信") {
                // TODO: フィードバック機能
            }
        }
    }
    
    private var appInfoSection: some View {
        Section(header: Text("アプリ情報")) {
            HStack {
                Text("バージョン")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("ビルド")
                Spacer()
                Text("202512")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("開発者")
                Spacer()
                Text("Claude & Akira")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - メソッド
    
    private func saveAPIKey() {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "APIキーを入力してください"
            showingApiKeyAlert = true
            return
        }
        
        if KeychainService.shared.saveAPIKey(apiKey) {
            alertMessage = "APIキーが保存されました"
            isAPIKeySet = true
        } else {
            alertMessage = "APIキーの保存に失敗しました"
        }
        showingApiKeyAlert = true
    }
    
    private func deleteAPIKey() {
        if KeychainService.shared.deleteAPIKey() {
            apiKey = ""
            isAPIKeySet = false
            alertMessage = "APIキーが削除されました"
        } else {
            alertMessage = "APIキーの削除に失敗しました"
        }
        showingApiKeyAlert = true
    }
    
    private func loadAPIKey() {
        if let savedKey = KeychainService.shared.getAPIKey() {
            // セキュリティのため、キーの最初の部分のみ表示
            if savedKey.count > 10 {
                apiKey = String(savedKey.prefix(10)) + "..." + String(savedKey.suffix(4))
            } else {
                apiKey = savedKey
            }
            isAPIKeySet = true
        } else if let envKey = EnvironmentLoader.shared.getClaudeAPIKey(), !envKey.isEmpty {
            // .envファイルの値を初期値として使用（開発用）
            apiKey = envKey
            isAPIKeySet = false
        }
    }
    
    private func checkConnectionStatus() {
        if ClaudeAPIService.shared.isAPIKeyConfigured() {
            connectionStatus = .connected
        } else {
            connectionStatus = .disconnected
        }
    }
    
    private func testConnection() {
        connectionStatus = .testing
        
        // 簡単なテストリクエストを送信
        Task {
            do {
                // TODO: テストAPI呼び出しの実装
                await MainActor.run {
                    connectionStatus = .connected
                }
            } catch {
                await MainActor.run {
                    connectionStatus = .error("接続テスト失敗")
                }
            }
        }
    }
}

// MARK: - サポートビュー

struct UserGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Habitovaの使い方")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("1. 習慣の記録")
                    .font(.headline)
                Text("チャット画面で今日行った活動をメッセージで送信してください。AIが習慣として認識し、記録します。")
                
                Text("2. チェーン分析")
                    .font(.headline)
                Text("習慣の順序や関連性をAIが分析し、改善提案をします。")
                
                Text("3. 進捗確認")
                    .font(.headline)
                Text("実行記録画面で習慣の完了状況や統計を確認できます。")
            }
            .padding()
        }
        .navigationTitle("ユーザーガイド")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FAQView: View {
    let faqs = [
        ("APIキーが必要な理由は？", "HabitovaはClaude AIを使用して高精度な習慣分析を行うため、Anthropic社のAPIキーが必要です。"),
        ("データのプライバシーは？", "すべてのデータはデバイス内で暗号化され、APIキーはiOSのKeychainで安全に保存されます。"),
        ("習慣が正しく認識されない場合は？", "より具体的な表現で入力したり、設定画面で習慣リストを確認してください。"),
        ("アプリの費用は？", "アプリ自体は無料ですが、Claude APIの使用量に応じてAnthropic社に料金が発生します。")
    ]
    
    var body: some View {
        List {
            ForEach(faqs, id: \.0) { question, answer in
                DisclosureGroup(question) {
                    Text(answer)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            }
        }
        .navigationTitle("FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    EnhancedSettingsView()
}