import SwiftUI

struct EditCardView: View {
    @StateObject private var viewModel: EditCardEntryViewModel
    @Environment(\.dismiss) private var dismiss

    init(entry: CardEntryItem) {
        _viewModel = StateObject(wrappedValue: EditCardEntryViewModel(entry: entry))
    }

    var body: some View {
        Form {
            nicknameSection
            purchaseSection
            saleSection
            notesSection
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Edit Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { viewModel.saveEntry() }
                    .fontWeight(.semibold)
            }
        }
        .onChange(of: viewModel.isSaved) { _, saved in
            if saved { dismiss() }
        }
    }

    private var nicknameSection: some View {
        Section {
            TextField("Nickname", text: $viewModel.nickname)
        } header: {
            Label("Entry Name", systemImage: "tag")
        }
    }

    private var purchaseSection: some View {
        Section {
            DatePicker("Purchase Date", selection: $viewModel.purchaseDate, displayedComponents: .date)
            HStack {
                Text("Price")
                Spacer()
                Text("$").foregroundStyle(.secondary)
                TextField("0", value: $viewModel.purchasePrice, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Label("Purchase", systemImage: "bag.fill")
        }
    }

    private var saleSection: some View {
        Section {
            Toggle("Mark as Sold", isOn: $viewModel.hasSold).tint(.green)
            if viewModel.hasSold {
                DatePicker("Sell Date", selection: $viewModel.sellDate, displayedComponents: .date)
                HStack {
                    Text("Price")
                    Spacer()
                    Text("$").foregroundStyle(.secondary)
                    TextField("0", value: $viewModel.sellPrice, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
        } header: {
            Label("Sale", systemImage: "tag.fill")
        }
    }

    private var notesSection: some View {
        Section {
            TextField("Add notes...", text: $viewModel.note, axis: .vertical)
                .lineLimit(3...6)
        } header: {
            Label("Notes", systemImage: "note.text")
        }
    }
}
