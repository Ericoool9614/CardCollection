import SwiftUI

struct CardDetailView: View {
    @StateObject private var viewModel: CardDetailViewModel
    @State private var showingEdit = false
    @State private var showSaveResult = false
    @State private var saveResultMessage = ""
    @Environment(\.dismiss) private var dismiss

    init(entry: CardEntryItem) {
        _viewModel = StateObject(wrappedValue: CardDetailViewModel(entry: entry))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                heroSection
                cardsListSection
                purchaseSection
                if viewModel.entry.isSold { saleSection }
                if let note = viewModel.entry.note, !note.isEmpty { notesSection }
                priceHistoryLink
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingEdit = true } label: {
                    Image(systemName: "pencil.circle.fill").font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack { EditCardView(entry: viewModel.entry) }
        }
        .alert("保存结果", isPresented: $showSaveResult) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(saveResultMessage)
        }
    }

    private var heroSection: some View {
        VStack(spacing: 8) {
            heroImage
            Text(viewModel.entry.displayName)
                .font(.title2.weight(.bold))
            if viewModel.entry.cardCount > 1 {
                Text("\(viewModel.entry.cardCount) 张卡牌")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                if viewModel.entry.hasPSA {
                    Text("评级").font(.caption.weight(.bold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15)).foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
                if viewModel.entry.isSold {
                    Text("已出售").font(.caption.weight(.bold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.green.opacity(0.15)).foregroundStyle(.green)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.top, 8)
    }

    private var cardsListSection: some View {
        DetailSection(title: "卡牌列表", icon: "rectangle.on.rectangle.angled", tint: .orange) {
            VStack(spacing: 12) {
                ForEach(viewModel.entry.subcards) { card in
                    SubCardRow(card: card) {
                        saveCardImagesToAlbum(card)
                    }
                }
            }
        }
    }

    private func saveCardImagesToAlbum(_ card: SubCardItem) {
        let paths = card.allImagePaths
        guard !paths.isEmpty else {
            saveResultMessage = "没有可保存的图片"
            showSaveResult = true
            return
        }
        var savedCount = 0
        var failCount = 0
        for path in paths {
            if let image = UIImage(contentsOfFile: path) {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                savedCount += 1
            } else {
                failCount += 1
            }
        }
        if failCount == 0 {
            saveResultMessage = "已保存 \(savedCount) 张图片到相册"
        } else {
            saveResultMessage = "保存 \(savedCount) 张成功，\(failCount) 张失败"
        }
        showSaveResult = true
    }

    private var purchaseSection: some View {
        DetailSection(title: "购买信息", icon: "bag.fill", tint: .blue) {
            VStack(spacing: 10) {
                if let date = viewModel.formattedPurchaseDate {
                    InfoRow(label: "购买日期", value: date)
                }
                InfoRow(label: "购买价格", value: viewModel.formattedPurchasePrice ?? "未记录")
            }
        }
    }

    private var saleSection: some View {
        DetailSection(title: "出售信息", icon: "tag.fill", tint: .green) {
            VStack(spacing: 10) {
                if let date = viewModel.formattedSellDate {
                    InfoRow(label: "出售日期", value: date)
                }
                if let price = viewModel.formattedSellPrice {
                    InfoRow(label: "出售价格", value: price)
                }
                if let profitDisplay = viewModel.profitDisplay {
                    InfoRow(label: "盈亏", value: profitDisplay, valueColor: viewModel.profitColor)
                }
            }
        }
    }

    private var notesSection: some View {
        DetailSection(title: "备注", icon: "note.text", tint: .yellow) {
            Text(viewModel.entry.note ?? "")
                .font(.subheadline).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var heroImage: some View {
        let images = viewModel.entry.frontImages
        if let firstPath = images.first, let uiImage = UIImage(contentsOfFile: firstPath) {
            if images.count == 1 {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, path in
                            if let img = UIImage(contentsOfFile: path) {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                            }
                        }
                    }
                }
            }
        } else {
            ZStack {
                LinearGradient(
                    colors: [viewModel.entry.hasPSA ? .orange.opacity(0.4) : .purple.opacity(0.4),
                             viewModel.entry.hasPSA ? .orange.opacity(0.1) : .purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: viewModel.entry.hasPSA ? "shield.checkered" : "rectangle.on.rectangle.angled")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var priceHistoryLink: some View {
        NavigationLink {
            PriceHistoryView(cardId: viewModel.entry.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis").font(.title3).foregroundStyle(.blue)
                Text("价格历史").font(.body.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

struct SubCardRow: View {
    let card: SubCardItem
    let onDownload: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if card.hasFrontImage, let path = card.frontImagePath,
               let uiImage = UIImage(contentsOfFile: path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(card.isPSA ? Color.orange.opacity(0.15) : Color.purple.opacity(0.15))
                    .frame(width: 50, height: 70)
                    .overlay {
                        Image(systemName: card.isPSA ? "shield.checkered" : "rectangle.on.rectangle.angled")
                            .font(.caption).foregroundStyle(card.isPSA ? .orange : .purple)
                    }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(card.name).font(.subheadline.weight(.medium)).lineLimit(1)
                if let set = card.set { Text(set).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                Text(card.gradeDisplay)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(gradeColor.opacity(0.15)).foregroundStyle(gradeColor)
                    .clipShape(Capsule())
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let pop = card.population, pop > 0 {
                    Text("Pop: \(pop)").font(.caption2).foregroundStyle(.secondary)
                }

                if !card.allImagePaths.isEmpty {
                    Button {
                        onDownload()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding(10)
        .background(Color(.systemBackground).opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private var gradeColor: Color {
        guard card.isPSA, let grade = card.grade else { return .purple }
        switch grade {
        case 10: return .green
        case 9: return .blue
        case 8: return .orange
        default: return .red
        }
    }
}

struct DetailSection<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(tint).font(.subheadline.weight(.semibold))
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            }
            content()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.medium)).foregroundStyle(valueColor)
        }
    }
}

extension Optional where Wrapped == String {
    var isEmptyOrNil: Bool { self?.isEmpty ?? true }
}
