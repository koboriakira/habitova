//
//  KeychainService.swift
//  Habitova
//
//  Created by Claude on 2025/12/22.
//

import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()
    private init() {}
    
    // Keychainのサービス名（アプリ固有）
    private let service = "com.koboriakira.habitova"
    
    /// APIキーを保存
    func saveAPIKey(_ apiKey: String) -> Bool {
        let data = apiKey.data(using: .utf8) ?? Data()
        return save(key: "claude_api_key", data: data)
    }
    
    /// APIキーを取得
    func getAPIKey() -> String? {
        guard let data = load(key: "claude_api_key") else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// APIキーを削除
    func deleteAPIKey() -> Bool {
        return delete(key: "claude_api_key")
    }
    
    // MARK: - Private Keychain Methods
    
    private func save(key: String, data: Data) -> Bool {
        // 既存のアイテムを削除
        delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        return nil
    }
    
    private func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}