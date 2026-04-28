import SwiftUI
import PhotosUI

struct EditCardView: View {
    @StateObject private var viewModel: EditCardEntryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItems: [UUID: PhotosPickerItem] = [:]

    init(entry: CardEntryItem) {
        _viewModel = StateObject(wrappedValue: EditCardEntryViewModel(entry: entry))
    }

    var body: some View {
        Form {
            nicknameSection
            ForEach(Array(viewModel.subcards.indices), id: \.self) { index in
                cardInfoSection(index: index)
                cardImageSection(index: index)
            }
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
        .alert("提示", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("确定") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var nicknameSection: some View {
        Section {
            TextField("昵称", text: $viewModel.nickname)
            Picker("语言版本", selection: $viewModel.language) {
                ForEach(CardLanguage.allCases, id: \.rawValue) { lang in
                    Text(lang.rawValue).tag(lang.rawValue)
                }
            }
        } header: {
            Label("条目名称", systemImage: "tag")
        }
    }

    // MARK: - 卡牌基本信息 Section（名称、系列、编号）
    private func cardInfoSection(index: Int) -> some View {
        let card = viewModel.subcards[index]

        return Section {
            HStack {
                Text(card.name.isEmpty ? "卡牌 \(index + 1)" : card.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer()
                if card.isPSA {
                    Text(card.gradingCompanyEnum.rawValue)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(card.gradingCompanyEnum.displayColor.opacity(0.15))
                        .foregroundStyle(card.gradingCompanyEnum.displayColor)
                        .clipShape(Capsule())
                } else {
                    Text("裸卡")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15)).foregroundStyle(.purple)
                        .clipShape(Capsule())
                }
            }

            TextField("卡名", text: Binding(
                get: { viewModel.subcards[index].name },
                set: { viewModel.updateSubcardName(at: index, $0) }
            ))

            HStack {
                TextField("系列", text: Binding(
                    get: { viewModel.subcards[index].set ?? "" },
                    set: { viewModel.updateSubcardSet(at: index, $0) }
                ))
                .frame(maxWidth: .infinity)
                TextField("编号", text: Binding(
                    get: { viewModel.subcards[index].number ?? "" },
                    set: { viewModel.updateSubcardNumber(at: index, $0) }
                ))
                .frame(width: 80)
            }

            if card.isPSA {
                gradingCompanyRow(index: index, card: card)
                gradeRow(index: index, card: card)

                if let cert = card.psaCertNumber, !cert.isEmpty {
                    HStack {
                        Text("PSA编号")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(cert)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Label("卡牌信息", systemImage: "rectangle.on.rectangle.angled")
        }
    }

    // MARK: - 评级公司选择（使用 .menu 样式避免 Form 导航验证）
    private func gradingCompanyRow(index: Int, card: SubCardItem) -> some View {
        let selection = viewModel.subcards[index].gradingCompany.isEmpty
            ? GradingCompany.default.rawValue
            : viewModel.subcards[index].gradingCompany

        return Picker("评级公司", selection: Binding(
            get: { selection },
            set: { viewModel.updateSubcardGradingCompany(at: index, $0) }
        )) {
            ForEach(GradingCompany.allCases, id: \.rawValue) { company in
                Text(company.rawValue).tag(company.rawValue)
            }
        }
        .pickerStyle(.menu)
    }

    // MARK: - 分数选择（使用 .menu 样式避免 Form 导航验证）
    @ViewBuilder
    private func gradeRow(index: Int, card: SubCardItem) -> some View {
        if card.gradingCompanyEnum.isFreeTextInput {
            HStack {
                Text("分数")
                    .font(.subheadline)
                Spacer()
                TextField("输入评级分数", text: Binding(
                    get: { viewModel.subcards[index].grade ?? "" },
                    set: { viewModel.updateSubcardGrade(at: index, $0.isEmpty ? nil : $0) }
                ))
                .multilineTextAlignment(.trailing)
            }
        } else {
            let validGrade: String = {
                guard let g = viewModel.subcards[index].grade, !g.isEmpty else { return "" }
                return card.gradingCompanyEnum.gradeOptions.contains(g) ? g : ""
            }()
            Picker("分数", selection: Binding(
                get: { validGrade },
                set: { viewModel.updateSubcardGrade(at: index, $0.isEmpty ? nil : $0) }
            )) {
                Text("请选择").tag("")
                ForEach(card.gradingCompanyEnum.gradeOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - 图片 Section（独立于卡牌信息，避免受 Picker 验证影响）
    private func cardImageSection(index: Int) -> some View {
        let card = viewModel.subcards[index]
        let hasPSAFrontImage = card.psaImageFrontPath != nil && !card.psaImageFrontPath!.isEmpty
        let hasLocalImage = card.localImagePath != nil && !card.localImagePath!.isEmpty

        return Section {
            if hasPSAFrontImage || hasLocalImage {
                existingImagesRow(index: index, card: card, hasPSAFrontImage: hasPSAFrontImage, hasLocalImage: hasLocalImage)
            }

            HStack(spacing: 12) {
                PhotosPicker(selection: Binding(
                    get: { selectedPhotoItems[card.id] },
                    set: { newItem in
                        guard let newItem else { return }
                        selectedPhotoItems[card.id] = newItem
                        Task {
                            if let data = try? await newItem.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                await viewModel.setLocalImage(at: index, image: image)
                            }
                            selectedPhotoItems.removeValue(forKey: card.id)
                        }
                    }
                ), matching: .images) {
                    Label("添加图片", systemImage: "photo.badge.plus")
                        .foregroundStyle(.orange)
                }

                if hasLocalImage {
                    Button(role: .destructive) {
                        Task { await viewModel.removeLocalImage(at: index) }
                    } label: {
                        Label("移除图片", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
        } header: {
            Label("卡牌图片", systemImage: "photo")
        }
    }

    @ViewBuilder
    private func existingImagesRow(index: Int, card: SubCardItem, hasPSAFrontImage: Bool, hasLocalImage: Bool) -> some View {
        HStack(spacing: 12) {
            if hasPSAFrontImage {
                let resolved = ImageStorageService.resolvePath(card.psaImageFrontPath!)
                if FileManager.default.fileExists(atPath: resolved),
                   let uiImage = UIImage(contentsOfFile: resolved) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            if let backPath = card.psaImageBackPath, !backPath.isEmpty {
                let resolved = ImageStorageService.resolvePath(backPath)
                if FileManager.default.fileExists(atPath: resolved),
                   let uiImage = UIImage(contentsOfFile: resolved) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            if hasLocalImage {
                let resolved = ImageStorageService.resolvePath(card.localImagePath!)
                if FileManager.default.fileExists(atPath: resolved),
                   let uiImage = UIImage(contentsOfFile: resolved) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            Spacer()
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
