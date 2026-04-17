import SwiftUI

struct AddPSACardView: View {
    @StateObject private var viewModel = AddCardEntryViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var initialCertNumber: String?
    @State private var autoFetch: Bool = false

    init(certNumber: String? = nil, autoFetch: Bool = false) {
        _initialCertNumber = State(initialValue: certNumber)
        _autoFetch = State(initialValue: autoFetch)
    }

    var body: some View {
        Form {
            nicknameSection
            cardsSection
            addCardButton
            purchaseSection
            saleSection
            notesSection
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("添加评级卡")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { viewModel.saveEntry() }
                    .disabled(!viewModel.canSave)
                    .fontWeight(.semibold)
            }
        }
        .alert("提示", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: viewModel.isSaved) { _, saved in
            if saved { dismiss() }
        }
        .onAppear {
            if viewModel.subcards.isEmpty {
                viewModel.addSubcard(isPSA: true)
            }
            if let cert = initialCertNumber, autoFetch {
                viewModel.setSubcardCertNumber(at: 0, cert)
                Task { await viewModel.fetchPSACard(at: 0) }
                autoFetch = false
            }
        }
    }

    private var nicknameSection: some View {
        Section {
            TextField("昵称（可选）", text: $viewModel.nickname)
        } header: {
            Label("条目名称", systemImage: "tag")
        }
    }

    private var cardsSection: some View {
        Section {
            if viewModel.subcards.isEmpty {
                Text("暂无卡牌").foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.subcards) { card in
                    subcardRow(card: card)
                }
            }
        } header: {
            Label("卡牌列表", systemImage: "rectangle.on.rectangle.angled")
        }
    }

    @ViewBuilder
    private func subcardRow(card: SubCardItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(card.name.isEmpty ? "卡牌 \(viewModel.indexOfCard(card) + 1)" : card.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Spacer()

                if viewModel.subcards.count > 1 {
                    Button(role: .destructive) {
                        viewModel.removeSubcard(id: card.id)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField("PSA 认证编号", text: Binding(
                    get: { card.psaCertNumber ?? "" },
                    set: { viewModel.setSubcardCertNumber(id: card.id, $0) }
                ))
                .keyboardType(.numberPad)

                Button {
                    Task { await viewModel.fetchPSACard(id: card.id) }
                } label: {
                    if viewModel.isFetchingPSA {
                        ProgressView()
                    } else {
                        Text("查询").font(.caption.weight(.bold))
                    }
                }
                .buttonStyle(.plain)
                .disabled(card.psaCertNumber?.isEmpty ?? true || viewModel.isFetchingPSA)
            }

            if !card.name.isEmpty {
                cardDetailPreview(card: card)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func cardDetailPreview(card: SubCardItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if let frontPath = card.psaImageFrontPath, !frontPath.isEmpty {
                    let resolved = ImageStorageService.resolvePath(frontPath)
                    if FileManager.default.fileExists(atPath: resolved),
                       let uiImage = UIImage(contentsOfFile: resolved) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 84)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                    }
                }

                if let backPath = card.psaImageBackPath, !backPath.isEmpty {
                    let resolved = ImageStorageService.resolvePath(backPath)
                    if FileManager.default.fileExists(atPath: resolved),
                       let uiImage = UIImage(contentsOfFile: resolved) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 84)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                    }
                }

                if card.psaImageFrontPath == nil && card.psaImageBackPath == nil {
                    Spacer()
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                LabeledContent("卡名", value: card.name)
                if let set = card.set { LabeledContent("系列", value: set) }
                if let number = card.number { LabeledContent("编号", value: number) }
                if let year = card.year { LabeledContent("年份", value: year) }
                if let grade = card.grade { LabeledContent("评级", value: "PSA \(grade)") }
                if let desc = card.gradeDescription { LabeledContent("评级描述", value: desc) }
                if let pop = card.population, pop > 0 { LabeledContent("Pop", value: "\(pop)") }
                if let variety = card.variety { LabeledContent("变体", value: variety) }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var addCardButton: some View {
        Section {
            Button {
                viewModel.addSubcard(isPSA: true)
            } label: {
                Label("添加更多卡牌", systemImage: "plus.circle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    private var purchaseSection: some View {
        Section {
            DatePicker("购买日期", selection: $viewModel.purchaseDate, displayedComponents: .date)
            HStack {
                Text("价格")
                Spacer()
                Text("¥").foregroundStyle(.secondary)
                TextField("0", value: $viewModel.purchasePrice, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Label("购买信息", systemImage: "bag.fill")
        }
    }

    private var saleSection: some View {
        Section {
            Toggle("标记为已出售", isOn: $viewModel.hasSold).tint(.green)
            if viewModel.hasSold {
                DatePicker("出售日期", selection: $viewModel.sellDate, displayedComponents: .date)
                HStack {
                    Text("价格")
                    Spacer()
                    Text("¥").foregroundStyle(.secondary)
                    TextField("0", value: $viewModel.sellPrice, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
        } header: {
            Label("出售信息", systemImage: "tag.fill")
        }
    }

    private var notesSection: some View {
        Section {
            TextField("添加备注...", text: $viewModel.note, axis: .vertical)
                .lineLimit(3...6)
        } header: {
            Label("备注", systemImage: "note.text")
        }
    }
}
