import SwiftUI

struct PriceHistoryView: View {
    @StateObject private var viewModel: PriceHistoryViewModel
    @Environment(\.dismiss) private var dismiss

    init(cardId: UUID) {
        _viewModel = StateObject(wrappedValue: PriceHistoryViewModel(cardId: cardId))
    }

    var body: some View {
        List {
            addEntrySection
            statsSection
            historySection
        }
        .navigationTitle("价格历史")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var addEntrySection: some View {
        Section {
            HStack {
                Text("¥").foregroundStyle(.secondary)
                TextField("价格", value: $viewModel.newPrice, format: .number)
                    .keyboardType(.decimalPad)
            }
            HStack {
                TextField("来源", text: $viewModel.newSource)
                Button("添加") {
                    viewModel.addEntry()
                }
                .disabled(viewModel.newPrice <= 0)
            }
        } header: {
            Text("添加价格记录")
        }
    }

    private var statsSection: some View {
        Section {
            if viewModel.entries.isEmpty {
                Text("暂无价格记录")
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    Text("最新价格")
                    Spacer()
                    Text("¥\(String(format: "%.2f", viewModel.entries.first?.price ?? 0))")
                        .fontWeight(.medium)
                }
                if let change = viewModel.priceChangeDisplay {
                    HStack {
                        Text("总变化")
                        Spacer()
                        Text(change)
                            .fontWeight(.medium)
                            .foregroundStyle(viewModel.priceChangeColor == "green" ? .green : .red)
                    }
                }
                HStack {
                    Text("记录数")
                    Spacer()
                    Text("\(viewModel.entries.count)")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("统计")
        }
    }

    private var historySection: some View {
        Section {
            ForEach(viewModel.entries) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("¥\(String(format: "%.2f", entry.price))")
                            .fontWeight(.medium)
                        Text(entry.source)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        viewModel.deleteEntry(entry)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        } header: {
            Text("历史记录")
        }
    }
}
