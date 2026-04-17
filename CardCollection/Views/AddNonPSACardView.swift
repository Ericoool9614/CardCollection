import SwiftUI
import PhotosUI

struct AddNonPSACardView: View {
    @StateObject private var viewModel = AddCardEntryViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        Form {
            nicknameSection
            cardInfoSection
            imageSection
            purchaseSection
            saleSection
            notesSection
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("添加裸卡")
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
        .onAppear {
            if viewModel.subcards.isEmpty {
                viewModel.addSubcard(isPSA: false)
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
            TextField("昵称（可选）", text: $viewModel.nickname)
        } header: {
            Label("条目名称", systemImage: "tag")
        }
    }

    private var cardInfoSection: some View {
        Section {
            if !viewModel.subcards.isEmpty {
                TextField("卡名 *", text: $viewModel.subcards[0].name)
                TextField("系列（可选）", text: Binding(
                    get: { viewModel.subcards[0].set ?? "" },
                    set: { viewModel.subcards[0].set = $0.isEmpty ? nil : $0 }
                ))
                TextField("编号（可选）", text: Binding(
                    get: { viewModel.subcards[0].number ?? "" },
                    set: { viewModel.subcards[0].number = $0.isEmpty ? nil : $0 }
                ))
            }
        } header: {
            Label("卡牌信息", systemImage: "rectangle.on.rectangle.angled")
        }
    }

    private var imageSection: some View {
        Section {
            if !viewModel.subcards.isEmpty {
                if let imagePath = viewModel.subcards[0].localImagePath,
                   !imagePath.isEmpty {
                    let resolvedPath = ImageStorageService.resolvePath(imagePath)
                    if FileManager.default.fileExists(atPath: resolvedPath),
                       let uiImage = UIImage(contentsOfFile: resolvedPath) {
                        VStack {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            Button("移除图片", role: .destructive) {
                                Task { await viewModel.removeLocalImage(at: 0) }
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
        } header: {
            Label("卡牌图片", systemImage: "photo")
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
