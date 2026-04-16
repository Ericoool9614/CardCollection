import SwiftUI

struct AddNonPSACardView: View {
    @StateObject private var viewModel = AddCardEntryViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            nicknameSection
            cardInfoSection
            purchaseSection
            saleSection
            notesSection
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Add Raw Card")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { viewModel.saveEntry() }
                    .disabled(!viewModel.canSave)
                    .fontWeight(.semibold)
            }
        }
        .onAppear {
            if viewModel.subcards.isEmpty {
                viewModel.addSubcard(isPSA: false)
            }
        }
        .onChange(of: viewModel.isSaved) { _, saved in
            if saved { dismiss() }
        }
    }

    private var nicknameSection: some View {
        Section {
            TextField("Nickname (optional)", text: $viewModel.nickname)
        } header: {
            Label("Entry Name", systemImage: "tag")
        }
    }

    private var cardInfoSection: some View {
        Section {
            if !viewModel.subcards.isEmpty {
                TextField("Card Name *", text: $viewModel.subcards[0].name)
                TextField("Set (optional)", text: Binding(
                    get: { viewModel.subcards[0].set ?? "" },
                    set: { viewModel.subcards[0].set = $0.isEmpty ? nil : $0 }
                ))
                TextField("Number (optional)", text: Binding(
                    get: { viewModel.subcards[0].number ?? "" },
                    set: { viewModel.subcards[0].number = $0.isEmpty ? nil : $0 }
                ))
            }
        } header: {
            Label("Card Info", systemImage: "rectangle.on.rectangle.angled")
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
