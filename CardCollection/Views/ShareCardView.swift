import SwiftUI
import UIKit

struct ShareCardView: View {
    let entries: [CardEntryItem]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEntries: Set<UUID> = []
    @State private var shareMode: ShareMode = .showcase
    @State private var askingPrices: [UUID: Double] = [:]
    @State private var generatedImage: UIImage?
    @State private var showShareSheet = false

    enum ShareMode: String, CaseIterable {
        case showcase = "展示卡牌"
        case forSale = "出售卡牌"
    }

    var body: some View {
        VStack(spacing: 0) {
            modePicker
            entryList
            generateButton
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("分享卡牌")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = generatedImage {
                ShareSheet(items: [image])
            }
        }
    }

    private var modePicker: some View {
        Picker("分享模式", selection: $shareMode) {
            ForEach(ShareMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var entryList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(entries) { entry in
                    entryRow(entry)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func entryRow(_ entry: CardEntryItem) -> some View {
        let isSelected = selectedEntries.contains(entry.id)

        Button {
            if isSelected {
                selectedEntries.remove(entry.id)
            } else {
                selectedEntries.insert(entry.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .orange : .secondary)
                    .font(.title3)

                if let path = entry.frontImages.first, let uiImage = UIImage(contentsOfFile: path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(width: 44, height: 60)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.tertiary)
                        }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("\(entry.cardCount)张 · \(entry.hasPSA ? "评级" : "裸卡")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(isSelected ? Color.orange.opacity(0.08) : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)

        if shareMode == .forSale && isSelected {
            HStack {
                Text("价格")
                    .font(.subheadline)
                Spacer()
                Text("¥").foregroundStyle(.secondary)
                TextField("0", value: Binding(
                    get: { askingPrices[entry.id] ?? 0 },
                    set: { askingPrices[entry.id] = $0 }
                ), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.leading, 36)
        }
    }

    private var generateButton: some View {
        VStack(spacing: 8) {
            Button {
                generateLongImage()
            } label: {
                HStack {
                    Image(systemName: "photo.stack.fill")
                    Text("生成长图")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selectedEntries.isEmpty ? Color.gray : Color.orange)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(selectedEntries.isEmpty)

            if generatedImage != nil {
                Button {
                    showShareSheet = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("分享长图")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private func generateLongImage() {
        let selected = entries.filter { selectedEntries.contains($0.id) }
        let isForSale = shareMode == .forSale

        let preloadedImages = preloadImages(for: selected)

        let renderer = ImageRenderer(content:
            LongImageView(entries: selected, isForSale: isForSale, askingPrices: askingPrices, preloadedImages: preloadedImages)
        )
        renderer.scale = 3.0

        if let image = renderer.uiImage {
            generatedImage = image
            showShareSheet = true
        }
    }

    private func preloadImages(for entries: [CardEntryItem]) -> [UUID: [UIImage]] {
        var result: [UUID: [UIImage]] = [:]
        for entry in entries {
            var images: [UIImage] = []
            for card in entry.subcards {
                if let path = card.frontImagePath,
                   let image = UIImage(contentsOfFile: path) {
                    images.append(image)
                }
            }
            result[entry.id] = images
        }
        return result
    }
}

struct LongImageView: View {
    let entries: [CardEntryItem]
    let isForSale: Bool
    let askingPrices: [UUID: Double]
    let preloadedImages: [UUID: [UIImage]]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(entries) { entry in
                entryRow(entry)
            }
        }
        .padding(20)
        .background(Color.white)
    }

    @ViewBuilder
    private func entryRow(_ entry: CardEntryItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(entry.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                if entry.cardCount > 1 {
                    Text("×\(entry.cardCount)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.orange)
                }
            }

            HStack(spacing: 8) {
                if let images = preloadedImages[entry.id] {
                    ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 110, height: 160)
                        .overlay {
                            Text(entry.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
            }

            if isForSale, let price = askingPrices[entry.id], price > 0 {
                HStack {
                    Spacer()
                    Text("¥\(String(format: "%.0f", price))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
