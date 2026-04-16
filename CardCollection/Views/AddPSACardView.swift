import SwiftUI

struct AddPSACardView: View {
    @StateObject private var viewModel = AddCardEntryViewModel()
    @Environment(\.dismiss) private var dismiss

    let initialCertNumber: String?
    let autoFetchOnAppear: Bool

    init(certNumber: String? = nil, autoFetch: Bool = false) {
        self.initialCertNumber = certNumber
        self.autoFetchOnAppear = autoFetch
    }

    var body: some View {
        Form {
            nicknameSection
            cardsTabSection
            purchaseSection
            saleSection
            notesSection
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Add PSA Cards")
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
                viewModel.addSubcard(isPSA: true)
            }
            if let cert = initialCertNumber, !cert.isEmpty {
                if !viewModel.subcards.isEmpty {
                    viewModel.subcards[0].psaCertNumber = cert
                }
                if autoFetchOnAppear {
                    Task { await viewModel.fetchPSAData(for: 0) }
                }
            }
        }
        .onChange(of: viewModel.isSaved) { _, saved in
            if saved { dismiss() }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var nicknameSection: some View {
        Section {
            TextField("Nickname (optional)", text: $viewModel.nickname)
        } header: {
            Label("Entry Name", systemImage: "tag")
        }
    }

    private var cardsTabSection: some View {
        Section {
            if viewModel.subcards.isEmpty {
                Text("No cards added")
                    .foregroundStyle(.secondary)
            } else {
                TabView(selection: $viewModel.selectedTab) {
                    ForEach(Array(viewModel.subcards.indices), id: \.self) { index in
                        SubCardEditView(
                            viewModel: viewModel,
                            index: index,
                            onRemove: index > 0 || viewModel.subcards.count > 1 ? {
                                viewModel.removeSubcard(at: index)
                            } : nil
                        )
                        .tag(index)
                    }
                }
                .frame(height: 320)
                .tabViewStyle(.page(indexDisplayMode: .always))
            }

            HStack {
                Button {
                    viewModel.addSubcard(isPSA: true)
                } label: {
                    Label("Add Card", systemImage: "plus.circle.fill")
                }
            }
        } header: {
            Label("Cards (\(viewModel.subcards.count))", systemImage: "rectangle.on.rectangle.angled")
        }
    }

    private var purchaseSection: some View {
        Section {
            DatePicker("Purchase Date", selection: $viewModel.purchaseDate, displayedComponents: .date)
            HStack {
                Text("Total Price")
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
                    Text("Total Price")
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

struct SubCardEditView: View {
    @ObservedObject var viewModel: AddCardEntryViewModel
    let index: Int
    let onRemove: (() -> Void)?
    @State private var isFetching = false

    private var card: SubCardItem {
        guard index < viewModel.subcards.count else { return SubCardItem.placeholder }
        return viewModel.subcards[index]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                certRow
                cardInfoRow
                psaDetailsRow
            }
            .padding(.horizontal, 16)
        }
    }

    private var certRow: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("PSA Cert Number", text: Binding(
                    get: { card.psaCertNumber ?? "" },
                    set: { viewModel.setSubcardCertNumber(at: index, $0) }
                ))
                .textFieldStyle(.roundedBorder)

                Button {
                    isFetching = true
                    Task {
                        await viewModel.fetchPSAData(for: index)
                        isFetching = false
                    }
                } label: {
                    if isFetching {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Fetch").fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled((card.psaCertNumber ?? "").isEmpty || isFetching)
            }

            if let onRemove = onRemove {
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Label("Remove Card", systemImage: "trash")
                        .font(.caption)
                }
            }
        }
    }

    private var cardInfoRow: some View {
        Group {
            TextField("Card Name *", text: Binding(
                get: { card.name },
                set: { viewModel.setSubcardName(at: index, $0) }
            ))
            .textFieldStyle(.roundedBorder)
            TextField("Set", text: Binding(
                get: { card.set ?? "" },
                set: { viewModel.setSubcardSet(at: index, $0) }
            ))
            .textFieldStyle(.roundedBorder)
            TextField("Number", text: Binding(
                get: { card.number ?? "" },
                set: { viewModel.setSubcardNumber(at: index, $0) }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }

    private var psaDetailsRow: some View {
        Group {
            if card.grade != nil || card.gradeDescription != nil {
                HStack {
                    Text("Grade").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text(card.gradeDisplay).font(.subheadline.weight(.medium))
                }
            }
            if let pop = card.population, pop > 0 {
                HStack {
                    Text("Population").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(pop)").font(.subheadline.weight(.medium))
                }
            }
            if card.psaImageFrontPath != nil {
                HStack {
                    Text("Front Image").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            if card.psaImageBackPath != nil {
                HStack {
                    Text("Back Image").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
        }
    }
}

extension SubCardItem {
    static var placeholder: SubCardItem {
        SubCardItem(
            id: UUID(), name: "", set: nil, number: nil, isPSA: true,
            psaCertNumber: nil, grade: nil, population: nil, populationHigher: nil,
            psaImageFrontPath: nil, psaImageBackPath: nil, localImagePath: nil,
            year: nil, variety: nil, gradeDescription: nil, category: nil,
            labelType: nil, sortOrder: 0
        )
    }
}
