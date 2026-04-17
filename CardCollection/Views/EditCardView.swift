import SwiftUI
import PhotosUI

struct EditCardView: View {
    @StateObject private var viewModel: EditCardEntryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItem: PhotosPickerItem?

    init(entry: CardEntryItem) {
        _viewModel = StateObject(wrappedValue: EditCardEntryViewModel(entry: entry))
    }

    var body: some View {
        Form {
            nicknameSection
            cardImagesSection
            purchaseSection
            saleSection
            notesSection
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("编辑条目")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { viewModel.saveEntry() }
                    .fontWeight(.semibold)
            }
        }
        .onChange(of: viewModel.isSaved) { _, saved in
            if saved { dismiss() }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                guard let newItem else { return }
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await viewModel.setLocalImage(at: 0, image: image)
                }
                selectedPhotoItem = nil
            }
        }
    }

    private var nicknameSection: some View {
        Section {
            TextField("昵称", text: $viewModel.nickname)
        } header: {
            Label("条目名称", systemImage: "tag")
        }
    }

    private var cardImagesSection: some View {
        Section {
            ForEach(Array(viewModel.subcards.indices), id: \.self) { index in
                let card = viewModel.subcards[index]
                VStack(alignment: .leading, spacing: 8) {
                    Text(card.name)
                        .font(.subheadline.weight(.medium))

                    if card.isPSA {
                        psaImageRow(card: card)
                    } else {
                        rawCardImageRow(index: index, card: card)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Label("卡牌图片", systemImage: "photo")
        }
    }

    private func psaImageRow(card: SubCardItem) -> some View {
        HStack {
            if let frontPath = card.psaImageFrontPath,
               !frontPath.isEmpty {
                let resolved = ImageStorageService.resolvePath(frontPath)
                if FileManager.default.fileExists(atPath: resolved),
                   let uiImage = UIImage(contentsOfFile: resolved) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    ImagePlaceholder(isPSA: true)
                }
            } else {
                ImagePlaceholder(isPSA: true)
            }

            Text("评级卡图片来自认证")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func rawCardImageRow(index: Int, card: SubCardItem) -> some View {
        VStack(spacing: 8) {
            if let imagePath = card.localImagePath, !imagePath.isEmpty {
                let resolved = ImageStorageService.resolvePath(imagePath)
                if FileManager.default.fileExists(atPath: resolved),
                   let uiImage = UIImage(contentsOfFile: resolved) {
                    HStack {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Spacer()

                        Button("移除", role: .destructive) {
                            Task { await viewModel.removeLocalImage(at: index) }
                        }
                        .font(.caption)
                    }
                } else {
                    imagePickerButton
                }
            } else {
                imagePickerButton
            }
        }
    }

    private var imagePickerButton: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            Label("选择照片", systemImage: "plus.circle.fill")
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

private struct ImagePlaceholder: View {
    let isPSA: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(isPSA ? Color.orange.opacity(0.15) : Color.purple.opacity(0.15))
            .frame(width: 50, height: 70)
            .overlay {
                Image(systemName: isPSA ? "shield.checkered" : "rectangle.on.rectangle.angled")
                    .font(.caption)
                    .foregroundStyle(isPSA ? .orange : .purple)
            }
    }
}
