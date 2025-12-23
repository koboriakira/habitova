//
//  SplashScreenView.swift
//  Habitova
//
//  Created by Claude on 2025/12/23.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var scale = 0.7
    @State private var opacity = 0.5
    
    var body: some View {
        ZStack {
            // 背景色
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.1),
                    Color.green.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // アプリアイコン（シンボルアイコンでブランドを表現）
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 80, weight: .ultraLight))
                    .foregroundColor(.blue)
                    .scaleEffect(scale)
                    .opacity(opacity)
                
                // アプリ名
                Text("Habitova")
                    .font(.system(size: 32, weight: .thin, design: .rounded))
                    .foregroundColor(.primary)
                    .opacity(opacity)
                
                // サブタイトル
                Text("習慣形成AIアシスタント")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.secondary)
                    .opacity(opacity * 0.8)
                
                Spacer()
                    .frame(height: 40)
                
                // 読み込みインジケーター
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(0.8)
                    
                    Text("初期化中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .opacity(opacity)
            }
            .padding()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

#Preview {
    SplashScreenView()
}