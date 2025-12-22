//
//  EnvironmentLoader.swift
//  Habitova
//
//  Created by Claude on 2025/12/22.
//

import Foundation

class EnvironmentLoader {
    static let shared = EnvironmentLoader()
    private init() {}
    
    private var envVariables: [String: String] = [:]
    private var isLoaded = false
    
    /// .envファイルを読み込む（ビルド時にコピーされたファイル）
    func loadEnvironment() {
        guard !isLoaded else { return }
        
        // まず、バンドル内の .env ファイルを確認
        if let envPath = Bundle.main.path(forResource: ".env", ofType: nil),
           let envContent = try? String(contentsOfFile: envPath, encoding: .utf8) {
            parseEnvironmentContent(envContent)
            isLoaded = true
            print("EnvironmentLoader: .envファイルを読み込みました（\(envVariables.count)個の変数）")
            return
        }
        
        // デバッグ用：DocumentsディレクトリやResourcesディレクトリにある .env ファイルを探す
        let fileManager = FileManager.default
        if let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let envPath = documentsPath.appendingPathComponent(".env")
            if let envContent = try? String(contentsOf: envPath, encoding: .utf8) {
                parseEnvironmentContent(envContent)
                isLoaded = true
                print("EnvironmentLoader: Documentsディレクトリの.envファイルを読み込みました")
                return
            }
        }
        
        print("EnvironmentLoader: .envファイルが見つかりません。ビルドスクリプトで開発環境の.envをコピーしてください。")
        isLoaded = true
    }
    
    /// 環境変数を取得
    func getValue(for key: String) -> String? {
        loadEnvironment()
        return envVariables[key]
    }
    
    /// Claude API キーを取得
    func getClaudeAPIKey() -> String? {
        return getValue(for: "CLAUDE_API_KEY")
    }
    
    /// .envファイルの内容をパース
    private func parseEnvironmentContent(_ content: String) {
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // 空行やコメント行をスキップ
            guard !trimmedLine.isEmpty,
                  !trimmedLine.hasPrefix("#") else { continue }
            
            // KEY=VALUE形式をパース
            let components = trimmedLine.components(separatedBy: "=")
            guard components.count >= 2 else { continue }
            
            let key = components[0].trimmingCharacters(in: .whitespaces)
            let value = components.dropFirst().joined(separator: "=")
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) // クォートを除去
            
            envVariables[key] = value
        }
    }
    
    /// 開発用: 全ての環境変数を表示（デバッグ用）
    func printAllVariables() {
        loadEnvironment()
        print("Environment variables:")
        for (key, value) in envVariables {
            // APIキーは部分的にマスク
            if key.contains("API") || key.contains("KEY") || key.contains("TOKEN") {
                let maskedValue = value.count > 10 ? 
                    String(value.prefix(6)) + "..." + String(value.suffix(4)) : 
                    String(repeating: "*", count: value.count)
                print("  \(key)=\(maskedValue)")
            } else {
                print("  \(key)=\(value)")
            }
        }
    }
}