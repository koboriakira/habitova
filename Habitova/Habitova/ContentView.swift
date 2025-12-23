//
//  ContentView.swift
//  Habitova
//
//  Created by Akira Kobori on 2025/12/21.
//

import SwiftUI
import SwiftData
// import ComposableArchitecture  // TCAパッケージ追加後にコメント解除

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var habits: [Habit]
    @State private var chatViewModel: SimpleChatViewModel?
    @State private var currentInput: String = ""
    @State private var showingSettings = false
    @State private var isInitializing = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                headerView
                
                // メッセージリスト
                if isInitializing {
                    // ローディング画面
                    VStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        Text("初期化中...")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                        Spacer()
                    }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if let viewModel = chatViewModel {
                                    ForEach(viewModel.messages) { message in
                                        MessageBubble(message: message)
                                            .id(message.id)
                                    }
                                    
                                    if viewModel.isLoading {
                                        HStack {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                            Text("AI が考え中...")
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .onChange(of: chatViewModel?.messages.count) { _ in
                            if let lastMessage = chatViewModel?.messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                
                Divider()
                
                // 入力エリア
                inputView
            }
            .navigationTitle("Habitova")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await initializeChatViewModel()
            }
            .sheet(isPresented: $showingSettings) {
                EnhancedSettingsView()
                    .onDisappear {
                        // 設定画面が閉じられたときにAPIキーを再読み込み
                        ClaudeAPIService.shared.reloadAPIKey()
                    }
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 4) {
            HStack {
                Text("習慣形成AIアシスタント")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    
                    NavigationLink(destination: HabitExecutionListView()) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    
                    NavigationLink(destination: HabitManagementView()) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    
                    if let chainReport = chatViewModel?.lastChainReport {
                        NavigationLink(destination: ChainConsistencyView(report: chainReport)) {
                            Image(systemName: "link.circle")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(chainReport.inconsistencyLevel > 0.3 ? .orange : .green)
                        }
                    }
                }
            }
            
            HStack {
                Text("今日の活動を教えてください")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("習慣数: \(habits.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private var inputView: some View {
        HStack(spacing: 12) {
            // 入力フィールドを即座に有効化
            TextField("今日何をしましたか？", text: $currentInput, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .disabled(chatViewModel?.isLoading ?? false || isInitializing)
            
            Button(action: {
                guard let viewModel = chatViewModel, !isInitializing else { return }
                print("ContentView: Send button tapped with input: \(currentInput)")
                Task {
                    print("ContentView: Starting sendMessage task")
                    viewModel.currentInput = currentInput
                    await viewModel.sendMessage()
                    currentInput = ""
                    print("ContentView: sendMessage task completed")
                }
            }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(
                                currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                                chatViewModel?.isLoading ?? false || 
                                isInitializing ? Color.gray : Color.blue
                            )
                    )
            }
            .disabled(
                currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                chatViewModel?.isLoading ?? false || 
                isInitializing
            )
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    private func connectionStatusView(for viewModel: SimpleChatViewModel) -> some View {
        Group {
            if viewModel.connectionStatus != .connected {
                HStack {
                    Image(systemName: "wifi.exclamationmark")
                        .foregroundColor(viewModel.connectionStatus.color)
                    
                    Text(viewModel.connectionStatus.displayText)
                        .font(.caption)
                        .foregroundColor(viewModel.connectionStatus.color)
                    
                    Spacer()
                    
                    if case .error = viewModel.connectionStatus {
                        Button("設定") {
                            showingSettings = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(viewModel.connectionStatus.color.opacity(0.1))
            }
        }
    }
    
    /// チャットViewModelの非同期初期化
    @MainActor
    private func initializeChatViewModel() async {
        guard chatViewModel == nil else { return }
        
        // 短い遅延でUIの即座表示を保証
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // ViewModelの初期化をメインアクターで実行
        let viewModel = SimpleChatViewModel(modelContext: modelContext)
        
        // UIの更新をスムーズに見せるため短い遅延を挟む
        withAnimation(.easeOut(duration: 0.3)) {
            self.chatViewModel = viewModel
            self.isInitializing = false
        }
    }
}

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.sender == .user {
                Spacer(minLength: 50)
                
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemGray5))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    
                    Text(message.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 16)
                }
                
                Spacer(minLength: 50)
            }
        }
    }
}


#Preview {
    ContentView()
        .modelContainer(for: [Habit.self, Message.self, HabitExecution.self, HabitovaTask.self, ExecutionInference.self, HabitChain.self], inMemory: true)
}
