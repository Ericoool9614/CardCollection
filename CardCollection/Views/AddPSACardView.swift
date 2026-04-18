import SwiftUI
import AVFoundation

struct AddPSACardView: View {
    @StateObject private var viewModel = AddCardEntryViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var initialCertNumber: String?
    @State private var autoFetch: Bool = false
    @State private var showScanner = false

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
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.showBatchAdd = true
                } label: {
                    Image(systemName: "list.number")
                }
            }
        }
        .alert("提示", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showScanner) {
            InlineScannerView { certNumber in
                viewModel.addSubcardWithCertNumber(certNumber)
                Task {
                    if let idx = viewModel.subcards.lastIndex(where: { $0.psaCertNumber == certNumber }) {
                        await viewModel.fetchPSACard(at: idx)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showBatchAdd) {
            batchAddSheet
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
                Button {
                    showScanner = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)

                TextField("PSA编号", text: Binding(
                    get: { card.psaCertNumber ?? "" },
                    set: { viewModel.setSubcardCertNumber(id: card.id, $0) }
                ))
                .keyboardType(.numberPad)

                Button {
                    Task { await viewModel.fetchPSACard(id: card.id) }
                } label: {
                    if viewModel.isFetching(id: card.id) {
                        ProgressView()
                    } else {
                        Text("查询").font(.caption.weight(.bold))
                    }
                }
                .buttonStyle(.plain)
                .disabled(card.psaCertNumber?.isEmpty ?? true || viewModel.isFetching(id: card.id))
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

    private var batchAddSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("批量添加评级卡")
                        .font(.headline)
                    Text("输入起始和结束PSA编号，系统将自动查询并添加对应卡牌")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    HStack {
                        Text("起始编号")
                        TextField("如 133880400", text: $viewModel.batchStartNumber)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("结束编号")
                        TextField("如 133880450", text: $viewModel.batchEndNumber)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.horizontal, 20)

                if viewModel.isBatchFetching {
                    VStack(spacing: 8) {
                        ProgressView(value: viewModel.batchProgress)
                        Text("正在查询... \(Int(viewModel.batchProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()

                Button {
                    Task { await viewModel.batchFetchPSACards() }
                } label: {
                    Text("开始查询")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(viewModel.isBatchFetching ? Color.gray : Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(viewModel.isBatchFetching || viewModel.batchStartNumber.isEmpty || viewModel.batchEndNumber.isEmpty)
                .padding(.horizontal, 20)
            }
            .padding(.top, 20)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("批量添加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { viewModel.showBatchAdd = false }
                }
            }
        }
    }
}

struct InlineScannerView: View {
    let onScanned: (String) -> Void
    @StateObject private var scannerService = ScannerService()
    @State private var cameraPermissionGranted = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                if cameraPermissionGranted {
                    VStack {
                        ZStack {
                            ScannerPreviewView(session: scannerService.captureSession)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 16))

                            if scannerService.isScanning {
                                VStack {
                                    Spacer()
                                    Text("正在扫描...")
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Capsule())
                                    Spacer()
                                }
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange, lineWidth: 2))
                        .padding()

                        if let certNumber = scannerService.scannedCertNumber {
                            VStack(spacing: 12) {
                                Label("检测到编号：\(certNumber)", systemImage: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.green)

                                HStack(spacing: 16) {
                                    Button("添加并继续扫描") {
                                        onScanned(certNumber)
                                        scannerService.scannedCertNumber = nil
                                        scannerService.startScanning()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.orange)

                                    Button("完成") {
                                        onScanned(certNumber)
                                        dismiss()
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("需要相机权限")
                            .font(.title3.weight(.bold))
                        Button("授予权限") {
                            Task {
                                cameraPermissionGranted = await scannerService.requestCameraPermission()
                                if cameraPermissionGranted { scannerService.startScanning() }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                }
            }
            .navigationTitle("扫码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                if scannerService.checkCameraPermission() {
                    cameraPermissionGranted = true
                    scannerService.startScanning()
                }
            }
        }
    }
}
