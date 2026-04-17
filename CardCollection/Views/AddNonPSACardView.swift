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

                            Button("Remove Image", role: .destructive) {
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
            Label("Card Image", systemImage: "photo")
        }
    }

    private var imagePickerButton: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            Label("Select Photo", systemImage: "plus.circle.fill")
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
