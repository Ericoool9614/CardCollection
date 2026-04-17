import SwiftUI
import UniformTypeIdentifiers

struct CardListView: View {
    @StateObject private var viewModel = CardListViewModel()
    @State private var showingAddPSA = false
    @State private var showingAddNonPSA = false
    @State private var showingScanner = false
    @State private var selectedEntry: CardEntryItem?
    @State private var refreshTrigger = false
    @State private var csvExportURL: URL?
    @State private var showCSVShareSheet = false
    @State private var showSortSheet = false
    @State private var showShareView = false
    @State private var showCSVImportPicker = false
    @State private var csvImportURL: URL?
    @State private var columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            tabBar
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if viewModel.activeEntries.isEmpty {
                        emptyState
                    } else {
                        cardGrid
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemGroupedBackground))
        .searchable(text: $viewModel.searchText, prompt: "搜索名称、系列、昵称...")
        .navigationTitle("我的卡牌")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { showingAddPSA = true } label: {
                        Label("添加评级卡", systemImage: "shield.checkered")
                    }
                    Button { showingAddNonPSA = true } label: {
                        Label("添加裸卡", systemImage: "rectangle.on.rectangle.angled")
                    }
                    Button { showingScanner = true } label: {
                        Label("扫码添加", systemImage: "qrcode.viewfinder")
                    }
                    Divider()
                    Button { showSortSheet = true } label: {
                        Label("排序方式", systemImage: "arrow.up.arrow.down")
                    }
                    Button { showShareView = true } label: {
                        Label("分享卡牌", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Button { exportCSV() } label: {
                        Label("导出CSV", systemImage: "square.and.arrow.up")
                    }
                    Button { showCSVImportPicker = true } label: {
                        Label("导入CSV", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            }
        }
        .confirmationDialog("排序方式", isPresented: $showSortSheet, titleVisibility: .visible) {
            ForEach(SortOption.allCases, id: \.self) { option in
                Button(option.rawValue) {
                    viewModel.sortOption = option
                    viewModel.loadEntries()
                }
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showingAddPSA, onDismiss: { refreshTrigger.toggle() }) {
            NavigationStack { AddPSACardView() }
        }
        .sheet(isPresented: $showingAddNonPSA, onDismiss: { refreshTrigger.toggle() }) {
            NavigationStack { AddNonPSACardView() }
        }
        .sheet(isPresented: $showingScanner, onDismiss: { refreshTrigger.toggle() }) {
            ScanPSACardView()
        }
        .sheet(item: $selectedEntry, onDismiss: { refreshTrigger.toggle() }) { entry in
            NavigationStack { CardDetailView(entry: entry) }
        }
        .sheet(isPresented: $showCSVShareSheet) {
            if let url = csvExportURL { ShareSheet(items: [url]) }
        }
        .sheet(isPresented: $showShareView) {
            NavigationStack { ShareCardView(entries: viewModel.entries + viewModel.soldEntries) }
        }
        .fileImporter(isPresented: $showCSVImportPicker, allowedContentTypes: [UTType.commaSeparatedText], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    csvImportURL = url
                    importCSV(from: url)
                }
            case .failure:
                break
            }
        }
        .onChange(of: viewModel.searchText) { _, _ in viewModel.loadEntries() }
        .onChange(of: viewModel.filter) { _, _ in viewModel.loadEntries() }
        .onChange(of: refreshTrigger) { _, _ in viewModel.loadEntries() }
        .onAppear { viewModel.loadEntries() }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CardFilter.allCases, id: \.self) { f in
                    Button {
                        viewModel.filter = f
                    } label: {
                        Text(f.rawValue)
                            .font(.subheadline.weight(viewModel.filter == f ? .bold : .regular))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(viewModel.filter == f ? Color.orange : Color(.systemBackground))
                            .foregroundStyle(viewModel.filter == f ? .white : .secondary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "持有中", count: viewModel.entries.count, tag: 0)
            tabButton(title: "已出售", count: viewModel.soldEntries.count, tag: 1)
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(.systemGray4)).frame(height: 0.5)
        }
    }

    private func tabButton(title: String, count: Int, tag: Int) -> some View {
        Button {
            viewModel.selectedTab = tag
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(viewModel.selectedTab == tag ? .bold : .regular))
                        .foregroundStyle(viewModel.selectedTab == tag ? .primary : .secondary)
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(viewModel.selectedTab == tag ? Color.orange : Color.gray.opacity(0.4))
                        .clipShape(Capsule())
                }
                Rectangle()
                    .fill(viewModel.selectedTab == tag ? Color.orange : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("暂无卡牌")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("点击 + 添加第一张卡牌")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var cardGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(viewModel.activeEntries) { entry in
                EntryGridItem(entry: entry)
                    .onTapGesture { selectedEntry = entry }
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.deleteEntry(entry)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
            }
        }
    }

    private func exportCSV() {
        csvExportURL = CSVExportService.export(entries: viewModel.entries + viewModel.soldEntries)
        if csvExportURL != nil { showCSVShareSheet = true }
    }

    private func importCSV(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let entries = CSVImportService.importFrom(url: url) else { return }
        for entry in entries {
            PersistenceController.shared.createEntry(from: entry)
        }
        refreshTrigger.toggle()
    }
}

struct EntryGridItem: View {
    let entry: CardEntryItem

    private var firstImagePath: String? {
        guard let firstCard = entry.subcards.first else { return nil }
        let rawPath = firstCard.psaImageFrontPath ?? firstCard.localImagePath
        guard let path = rawPath, !path.isEmpty else { return nil }
        let resolved = ImageStorageService.resolvePath(path)
        return FileManager.default.fileExists(atPath: resolved) ? resolved : nil
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                cardImage
                cardInfo
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)

            if entry.isSold, let profit = entry.profit {
                Text(profit >= 0 ? "+¥\(String(format: "%.0f", profit))" : "-¥\(String(format: "%.0f", abs(profit)))")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(profit >= 0 ? Color.green : Color.red)
                    .foregroundStyle(.white)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 14, topTrailingRadius: 0))
            }
        }
    }

    private var cardImage: some View {
        Group {
            if let path = firstImagePath, let uiImage = UIImage(contentsOfFile: path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [entry.hasPSA ? .orange.opacity(0.3) : .purple.opacity(0.3),
                                 entry.hasPSA ? .orange.opacity(0.1) : .purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: entry.hasPSA ? "shield.checkered" : "rectangle.on.rectangle.angled")
                        .font(.title)
                        .foregroundStyle(entry.hasPSA ? .orange : .purple)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: 180)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))
    }

    private var cardInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if entry.cardCount > 1 {
                    Text("×\(entry.cardCount)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                }
            }

            if let firstCard = entry.primaryCard {
                Text(firstCard.set ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack {
                Text(entry.hasPSA ? "评级" : "裸卡")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(entry.hasPSA ? Color.orange.opacity(0.15) : Color.purple.opacity(0.15))
                    .foregroundStyle(entry.hasPSA ? .orange : .purple)
                    .clipShape(Capsule())

                Spacer()

                if !entry.isSold, let price = entry.purchasePrice {
                    Text("¥\(String(format: "%.0f", price))")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
