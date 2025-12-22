//
//  SettingsView.swift
//  Habitova
//
//  Created by Claude on 2025/12/22.
//

import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var showingApiKeyAlert = false
    @State private var alertMessage = ""
    @State private var isAPIKeySet = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Claude API設定")) {
                    VStack(alignment: .leading, spacing: 8) {
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
                    }
                    
                    Button(action: saveAPIKey) {
                        Text("保存")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: deleteAPIKey) {
                        Text("削除")
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("APIキー取得方法")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("1. Anthropic Console (console.anthropic.com) にアクセス")
                        Text("2. アカウントでログイン")
                        Text("3. 'API Keys' セクションで新しいキーを作成")
                        Text("4. 生成されたキーをコピーして上記に貼り付け")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Section(header: Text("セキュリティ")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("⚠️ 注意事項")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text("• APIキーは iOSのKeychainに暗号化されて保存されます")
                        Text("• デバイスから離れる際は、APIキーを削除することをお勧めします")
                        Text("• 本番アプリでは、バックエンド経由でのAPI呼び出しを推奨します")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("完了") { dismiss() })
            .onAppear(perform: loadAPIKey)
            .alert("API設定", isPresented: $showingApiKeyAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
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
}