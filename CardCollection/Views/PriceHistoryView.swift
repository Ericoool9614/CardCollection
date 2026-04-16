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
        .navigationTitle("Price History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var addEntrySection: some View {
        Section {
            HStack {
                Text("$")
                    .foregroundStyle(.secondary)
                TextField("Price", value: $viewModel.newPrice, format: .number)
                    .keyboardType(.decimalPad)
            }
            HStack {
                TextField("Source", text: $viewModel.newSource)
                Button("Add") {
                    viewModel.addEntry()
                }
                .disabled(viewModel.newPrice <= 0)
            }
        } header: {
            Text("Add Price Entry")
        }
    }

    private var statsSection: some View {
        Section {
            if viewModel.entries.isEmpty {
                Text("No price history yet")
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    Text("Latest Price")
                    Spacer()
                    Text("$\(String(format: "%.2f", viewModel.entries.first?.price ?? 0))")
                        .fontWeight(.medium)
                }
                if let change = viewModel.priceChangeDisplay {
                    HStack {
                        Text("Total Change")
                        Spacer()
                        Text(change)
                            .fontWeight(.medium)
                            .foregroundStyle(viewModel.priceChangeColor == "green" ? .green : .red)
                    }
                }
                HStack {
                    Text("Entries")
                    Spacer()
                    Text("\(viewModel.entries.count)")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Statistics")
        }
    }

    private var historySection: some View {
        Section {
            ForEach(viewModel.entries) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("$\(String(format: "%.2f", entry.price))")
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
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        } header: {
            Text("History")
        }
    }
}
