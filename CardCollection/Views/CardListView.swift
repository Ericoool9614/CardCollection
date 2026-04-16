import SwiftUI

struct CardListView: View {
    @StateObject private var viewModel = CardListViewModel()
    @State private var showingAddPSA = false
    @State private var showingAddNonPSA = false
    @State private var showingScanner = false
    @State private var selectedEntry: CardEntryItem?
    @State private var refreshTrigger = false
    @State private var csvExportURL: URL?
    @State private var showCSVShareSheet = false
    @State private var columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if viewModel.entries.isEmpty {
                    emptyState
                } else {
                    cardGrid
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .searchable(text: $viewModel.searchText, prompt: "Search name, set, nickname...")
        .navigationTitle("My Cards")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { showingAddPSA = true } label: {
                        Label("Add PSA Cards", systemImage: "shield.checkered")
                    }
                    Button { showingAddNonPSA = true } label: {
                        Label("Add Raw Card", systemImage: "rectangle.on.rectangle.angled")
                    }
                    Button { showingScanner = true } label: {
                        Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    }
                    Divider()
                    Button { exportCSV() } label: {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            }
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
        .onChange(of: viewModel.searchText) { _, _ in viewModel.loadEntries() }
        .onChange(of: refreshTrigger) { _, _ in viewModel.loadEntries() }
        .onAppear { viewModel.loadEntries() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No Cards Yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Tap + to add your first card")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var cardGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(viewModel.entries) { entry in
                EntryGridItem(entry: entry)
                    .onTapGesture { selectedEntry = entry }
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.deleteEntry(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }

    private func exportCSV() {
        csvExportURL = CSVExportService.export(entries: viewModel.entries)
        if csvExportURL != nil { showCSVShareSheet = true }
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
        VStack(spacing: 0) {
            cardImage
            cardInfo
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
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
                Text(entry.hasPSA ? "PSA" : "Raw")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(entry.hasPSA ? Color.orange.opacity(0.15) : Color.purple.opacity(0.15))
                    .foregroundStyle(entry.hasPSA ? .orange : .purple)
                    .clipShape(Capsule())

                Spacer()

                if let price = entry.purchasePrice {
                    Text("$\(String(format: "%.0f", price))")
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
