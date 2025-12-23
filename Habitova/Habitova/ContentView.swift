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
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                headerView
                
                // メッセージリスト
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
                            } else {
                                // ViewModelの初期化中
                                VStack {
                                    Spacer()
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    Text("チャット準備中...")
                                        .foregroundColor(.secondary)
                                        .padding(.top, 8)
                                    Spacer()
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
            // 入力フィールド（パフォーマンス最適化）
            TextField("今日何をしましたか？", text: $currentInput, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .disabled(chatViewModel?.isLoading ?? false)
                .submitLabel(.send)
                .onSubmit {
                    // Enterキーでも送信（一般的なチャット仕様）
                    sendMessage()
                }
                .onAppear {
                    // アプリ起動後のタップ応答性向上のためのwarming up
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // フォーカス状態を初期化することで、内部状態をウォームアップ
                        isInputFocused = false
                    }
                }
            
            Button(action: {
                sendMessage()
            }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(
                                currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                                chatViewModel?.isLoading ?? false ? Color.gray : Color.blue
                            )
                    )
            }
            .disabled(
                currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                chatViewModel?.isLoading ?? false
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
    
    /// メッセージ送信処理（ボタンとEnterキー両方から呼び出し）
    private func sendMessage() {
        // 入力チェック
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            return 
        }
        
        // ViewModelが初期化完了していない場合は一時的に保持
        guard let viewModel = chatViewModel else {
            print("ContentView: ViewModel not ready, message queued")
            // TODO: 必要に応じてメッセージキューイング実装
            return
        }
        
        print("ContentView: Send button tapped with input: \(currentInput)")
        
        // 送信開始と同時に入力フィールドをクリア（一般的なチャット仕様）
        let messageToSend = currentInput
        currentInput = ""
        
        // キーボードを隠す（UX向上）
        isInputFocused = false
        
        Task {
            print("ContentView: Starting sendMessage task")
            viewModel.currentInput = messageToSend
            await viewModel.sendMessage()
            print("ContentView: sendMessage task completed")
        }
    }
    
    /// チャットViewModelの非同期初期化
    @MainActor
    private func initializeChatViewModel() async {
        guard chatViewModel == nil else { return }
        
        // 即座にViewModelを初期化（入力フィールドの応答性向上）
        let viewModel = SimpleChatViewModel(modelContext: modelContext)
        
        // UIの更新をスムーズに見せる
        withAnimation(.easeOut(duration: 0.2)) {
            self.chatViewModel = viewModel
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
