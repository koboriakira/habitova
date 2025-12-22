//
//  DataExportView.swift
//  Habitova
//
//  Created by Claude on 2025/12/22.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var exportService = DataExportService.shared
    
    @State private var selectedFormat: DataExportService.ExportFormat = .json
    @State private var selectedScope: DataExportService.ExportScope = .all
    @State private var useDateRange = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    
    @State private var showingExportSheet = false
    @State private var exportedData: Data?
    @State private var exportFileName = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                // エクスポート設定
                exportSettingsSection
                
                // 日付範囲設定
                dateRangeSection
                
                // プレビュー
                previewSection
                
                // エクスポート実行
                exportActionSection
                
                // 履歴
                exportHistorySection
            }
            .navigationTitle("データエクスポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if exportService.isExporting {
                    exportProgressOverlay
                }
            }
            .fileExporter(
                isPresented: $showingExportSheet,
                document: ExportDocument(data: exportedData ?? Data(), filename: exportFileName),
                contentType: selectedFormat.utType,
                defaultFilename: exportFileName
            ) { result in
                handleExportResult(result)
            }
            .alert("エクスポート", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var exportSettingsSection: some View {
        Section(header: Text("エクスポート設定")) {
            // フォーマット選択
            VStack(alignment: .leading, spacing: 8) {
                Text("フォーマット")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(DataExportService.ExportFormat.allCases, id: \.self) { format in
                    HStack {
                        Button(action: {
                            selectedFormat = format
                        }) {
                            HStack {
                                Image(systemName: selectedFormat == format ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedFormat == format ? .blue : .gray)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(format.displayName)
                                        .font(.subheadline)
                                    Text(formatDescription(format))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .padding(.vertical, 4)
            
            Divider()
            
            // スコープ選択
            VStack(alignment: .leading, spacing: 8) {
                Text("データ範囲")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(DataExportService.ExportScope.allCases, id: \.self) { scope in
                    Button(action: {
                        selectedScope = scope
                    }) {
                        HStack {
                            Image(systemName: selectedScope == scope ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedScope == scope ? .blue : .gray)
                            
                            Text(scope.displayName)
                                .font(.subheadline)
                            
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var dateRangeSection: some View {
        Section(
            header: Text("日付範囲"),
            footer: Text("実行記録とメッセージに適用されます")
        ) {
            Toggle("日付範囲を指定", isOn: $useDateRange)
            
            if useDateRange {
                DatePicker(
                    "開始日",
                    selection: $startDate,
                    displayedComponents: .date
                )
                
                DatePicker(
                    "終了日",
                    selection: $endDate,
                    displayedComponents: .date
                )
            }
        }
    }
    
    private var previewSection: some View {
        Section(header: Text("プレビュー")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("フォーマット")
                    Spacer()
                    Text(selectedFormat.displayName)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("データ範囲")
                    Spacer()
                    Text(selectedScope.displayName)
                        .foregroundColor(.secondary)
                }
                
                if useDateRange {
                    HStack {
                        Text("期間")
                        Spacer()
                        Text("\(DateFormatter.shortDate.string(from: startDate)) - \(DateFormatter.shortDate.string(from: endDate))")
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("ファイル名")
                    Spacer()
                    Text(exportService.generateFileName(format: selectedFormat, scope: selectedScope))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
    
    private var exportActionSection: some View {
        Section {
            Button(action: {
                Task {
                    await performExport()
                }
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("データをエクスポート")
                    Spacer()
                }
            }
            .disabled(exportService.isExporting)
        }
    }
    
    private var exportHistorySection: some View {
        Section(header: Text("履歴")) {
            if let lastExportDate = exportService.lastExportDate {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text("最後のエクスポート")
                    Spacer()
                    Text(DateFormatter.fullDateTime.string(from: lastExportDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text("エクスポート履歴はありません")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var exportProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("データをエクスポート中...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                ProgressView(value: exportService.exportProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .frame(width: 200)
            }
            .padding(30)
            .background(Color.black.opacity(0.8))
            .cornerRadius(15)
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDescription(_ format: DataExportService.ExportFormat) -> String {
        switch format {
        case .json:
            return "構造化されたデータ形式、プログラムでの処理に適している"
        case .csv:
            return "表計算ソフトで開ける形式、Excel等で分析可能"
        case .txt:
            return "読みやすいテキスト形式、人間が読むのに適している"
        }
    }
    
    private func performExport() async {
        do {
            let dateRange = useDateRange ? DateInterval(start: startDate, end: endDate) : nil
            
            let data = try await exportService.exportData(
                format: selectedFormat,
                scope: selectedScope,
                context: modelContext,
                dateRange: dateRange
            )
            
            await MainActor.run {
                exportedData = data
                exportFileName = exportService.generateFileName(format: selectedFormat, scope: selectedScope)
                showingExportSheet = true
            }
            
        } catch {
            await MainActor.run {
                alertMessage = "エクスポートに失敗しました: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            alertMessage = "ファイルが保存されました: \(url.lastPathComponent)"
            showingAlert = true
            
        case .failure(let error):
            alertMessage = "ファイルの保存に失敗しました: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

// MARK: - Export Document

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.json, .commaSeparatedText, .plainText]
    
    let data: Data
    let filename: String
    
    init(data: Data, filename: String) {
        self.data = data
        self.filename = filename
    }
    
    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
        self.filename = "export"
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Preview

#Preview {
    DataExportView()
        .modelContainer(for: [Habit.self, HabitExecution.self, Message.self, HabitChain.self], inMemory: true)
}