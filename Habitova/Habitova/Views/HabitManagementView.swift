//
//  HabitManagementView.swift
//  Habitova
//
//  Created by Claude on 2025/12/22.
//

import SwiftUI
import SwiftData

struct HabitManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var habits: [Habit]
    @Query private var chains: [HabitChain]
    
    @State private var showingAddHabit = false
    @State private var showingEditHabit: Habit?
    @State private var selectedTab: ManagementTab = .habits
    @State private var searchText = ""
    @State private var showingImportanceFilter = false
    @State private var importanceFilterRange: ClosedRange<Double> = 0.0...1.0
    
    enum ManagementTab: String, CaseIterable {
        case habits = "習慣"
        case chains = "チェーン"
        case stats = "統計"
    }
    
    private var filteredHabits: [Habit] {
        let filtered = habits.filter { habit in
            let matchesSearch = searchText.isEmpty || habit.name.localizedCaseInsensitiveContains(searchText)
            let matchesImportance = (habit.importance ?? 0.5) >= importanceFilterRange.lowerBound && (habit.importance ?? 0.5) <= importanceFilterRange.upperBound
            return matchesSearch && matchesImportance && !habit.isArchived
        }
        return filtered.sorted { ($0.importance ?? 0.5) > ($1.importance ?? 0.5) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // タブ選択
                Picker("管理タブ", selection: $selectedTab) {
                    ForEach(ManagementTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // メインコンテンツ
                switch selectedTab {
                case .habits:
                    habitsListView
                case .chains:
                    chainsListView
                case .stats:
                    statsView
                }
            }
            .navigationTitle("習慣管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if selectedTab == .habits {
                        Button(action: { showingImportanceFilter.toggle() }) {
                            Image(systemName: "slider.horizontal.3")
                        }
                        
                        Button(action: { showingAddHabit = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "習慣を検索")
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView()
            }
            .sheet(item: $showingEditHabit) { habit in
                EditHabitView(habit: habit)
            }
            .sheet(isPresented: $showingImportanceFilter) {
                ImportanceFilterView(range: $importanceFilterRange)
            }
        }
    }
    
    // MARK: - ビューコンポーネント
    
    private var habitsListView: some View {
        List {
            if filteredHabits.isEmpty {
                ContentUnavailableView {
                    Label("習慣が見つかりません", systemImage: "magnifyingglass")
                } description: {
                    Text(searchText.isEmpty ? "新しい習慣を追加しましょう" : "検索条件を変更してください")
                }
            } else {
                ForEach(filteredHabits) { habit in
                    HabitRow(habit: habit) {
                        showingEditHabit = habit
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            archiveHabit(habit)
                        } label: {
                            Label("削除", systemImage: "archive")
                        }
                        
                        Button("編集") {
                            showingEditHabit = habit
                        }
                        .tint(.blue)
                    }
                }
                
                // 統計サマリー
                Section(footer: habitsSummaryFooter) {
                    EmptyView()
                }
            }
        }
    }
    
    private var chainsListView: some View {
        List {
            if chains.isEmpty {
                ContentUnavailableView {
                    Label("チェーンが設定されていません", systemImage: "link")
                } description: {
                    Text("習慣間の関連性が自動的に分析され、チェーンが作成されます")
                }
            } else {
                ForEach(chains) { chain in
                    ChainRow(chain: chain, habits: habits)
                }
            }
        }
    }
    
    private var statsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                HabitStatsOverview(habits: habits)
                HabitImportanceChart(habits: habits)
                HabitFrequencyChart(habits: habits)
            }
            .padding()
        }
    }
    
    private var habitsSummaryFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("合計 \(filteredHabits.count) 個の習慣")
            Text("平均重要度: \(String(format: "%.1f", filteredHabits.map { $0.importance ?? 0.5 }.reduce(0, +) / Double(max(filteredHabits.count, 1))))")
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
    
    // MARK: - アクション
    
    private func archiveHabit(_ habit: Habit) {
        withAnimation {
            habit.isArchived = true
            try? modelContext.save()
        }
    }
}

// MARK: - サブビュー

struct HabitRow: View {
    let habit: Habit
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(habit.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    ImportanceIndicator(importance: habit.importance ?? 0.5)
                }
                
                Text(habit.habitDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text(habit.targetFrequency)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                    
                    if habit.hiddenParameters != nil {
                        Text("詳細設定あり")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}

struct ImportanceIndicator: View {
    let importance: Double
    
    private var color: Color {
        switch importance {
        case 0.8...1.0: return .red
        case 0.6..<0.8: return .orange
        case 0.4..<0.6: return .yellow
        default: return .green
        }
    }
    
    private var text: String {
        switch importance {
        case 0.8...1.0: return "高"
        case 0.6..<0.8: return "中"
        case 0.4..<0.6: return "普"
        default: return "低"
        }
    }
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(Capsule())
    }
}

struct ChainRow: View {
    let chain: HabitChain
    let habits: [Habit]
    
    private var triggerHabitNames: [String] {
        chain.triggerHabits.compactMap { id in
            habits.first { $0.id == id }?.name
        }
    }
    
    private var nextHabitName: String {
        habits.first { $0.id == chain.nextHabitId }?.name ?? "不明な習慣"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.blue)
                Text("習慣チェーン")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: "%.0f", (chain.confidence ?? 0.0) * 100))%")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("トリガー: \(triggerHabitNames.joined(separator: ", "))")
                    .font(.subheadline)
                
                Text("→ \(nextHabitName)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if chain.delayMinutes > 0 {
                    Text("\(chain.delayMinutes)分後")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 統計ビュー

struct HabitStatsOverview: View {
    let habits: [Habit]
    
    private var stats: (total: Int, high: Int, medium: Int, low: Int) {
        let total = habits.count
        let high = habits.filter { ($0.importance ?? 0.5) >= 0.7 }.count
        let medium = habits.filter { let imp = $0.importance ?? 0.5; return imp >= 0.4 && imp < 0.7 }.count
        let low = habits.filter { ($0.importance ?? 0.5) < 0.4 }.count
        return (total, high, medium, low)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("習慣概要")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatCard(title: "総数", value: "\(stats.total)", color: .blue)
                StatCard(title: "重要", value: "\(stats.high)", color: .red)
                StatCard(title: "中程度", value: "\(stats.medium)", color: .orange)
                StatCard(title: "軽微", value: "\(stats.low)", color: .green)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct HabitImportanceChart: View {
    let habits: [Habit]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("重要度分布")
                .font(.headline)
            
            // 簡易的な棒グラフ
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<10, id: \.self) { bucket in
                    let range = Double(bucket) * 0.1...Double(bucket + 1) * 0.1
                    let count = habits.filter { range.contains($0.importance ?? 0.5) }.count
                    
                    VStack {
                        Rectangle()
                            .fill(Color.blue.opacity(0.6))
                            .frame(width: 20, height: CGFloat(count * 10))
                        Text("\(bucket)")
                            .font(.caption2)
                    }
                }
            }
            .frame(height: 100)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct HabitFrequencyChart: View {
    let habits: [Habit]
    
    private var frequencyData: [String: Int] {
        let frequencies = habits.map(\.targetFrequency)
        return Dictionary(grouping: frequencies, by: { $0 }).mapValues(\.count)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("頻度分布")
                .font(.headline)
            
            ForEach(Array(frequencyData.keys.sorted()), id: \.self) { frequency in
                HStack {
                    Text(frequency)
                        .font(.subheadline)
                    Spacer()
                    Text("\(frequencyData[frequency] ?? 0)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 編集ビュー

struct AddHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var description = ""
    @State private var importance = 0.5
    @State private var frequency = "daily"
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本情報") {
                    TextField("習慣名", text: $name)
                    TextField("説明", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("設定") {
                    VStack(alignment: .leading) {
                        Text("重要度: \(String(format: "%.1f", importance))")
                        Slider(value: $importance, in: 0.0...1.0)
                    }
                    
                    Picker("頻度", selection: $frequency) {
                        Text("毎日").tag("daily")
                        Text("週に数回").tag("weekly")
                        Text("月に数回").tag("monthly")
                    }
                }
            }
            .navigationTitle("新しい習慣")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveHabit()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveHabit() {
        let newHabit = Habit(
            name: name,
            habitDescription: description,
            targetFrequency: frequency,
            importance: importance
        )
        modelContext.insert(newHabit)
        try? modelContext.save()
    }
}

struct EditHabitView: View {
    let habit: Habit
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var description = ""
    @State private var importance = 0.5
    @State private var frequency = "daily"
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本情報") {
                    TextField("習慣名", text: $name)
                    TextField("説明", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("設定") {
                    VStack(alignment: .leading) {
                        Text("重要度: \(String(format: "%.1f", importance))")
                        Slider(value: $importance, in: 0.0...1.0)
                    }
                    
                    Picker("頻度", selection: $frequency) {
                        Text("毎日").tag("daily")
                        Text("週に数回").tag("weekly")
                        Text("月に数回").tag("monthly")
                    }
                }
                
                Section("詳細設定") {
                    if habit.hiddenParameters != nil {
                        Text("隠れパラメーター設定済み")
                            .foregroundColor(.secondary)
                    } else {
                        Text("隠れパラメーターなし")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("習慣を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                loadHabitData()
            }
        }
    }
    
    private func loadHabitData() {
        name = habit.name
        description = habit.habitDescription
        importance = habit.importance ?? 0.5
        frequency = habit.targetFrequency
    }
    
    private func saveChanges() {
        habit.name = name
        habit.habitDescription = description
        habit.importance = importance
        habit.targetFrequency = frequency
        try? modelContext.save()
    }
}

struct ImportanceFilterView: View {
    @Binding var range: ClosedRange<Double>
    @Environment(\.dismiss) private var dismiss
    
    @State private var lowerBound = 0.0
    @State private var upperBound = 1.0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("重要度フィルター")
                    .font(.headline)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("最小値: \(String(format: "%.1f", lowerBound))")
                    Slider(value: $lowerBound, in: 0.0...1.0)
                    
                    Text("最大値: \(String(format: "%.1f", upperBound))")
                    Slider(value: $upperBound, in: 0.0...1.0)
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("フィルター")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("適用") {
                        range = min(lowerBound, upperBound)...max(lowerBound, upperBound)
                        dismiss()
                    }
                }
            }
            .onAppear {
                lowerBound = range.lowerBound
                upperBound = range.upperBound
            }
        }
    }
}

#Preview {
    HabitManagementView()
        .modelContainer(for: [Habit.self, HabitChain.self, HabitExecution.self], inMemory: true)
}