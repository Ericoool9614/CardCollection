import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                heroSection
                summaryCards
                detailSections
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Collection")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { viewModel.loadDashboard() }
        .refreshable { viewModel.loadDashboard() }
    }

    private var heroSection: some View {
        VStack(spacing: 6) {
            Text("Pokémon Cards")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("\(viewModel.totalEntries) entries, \(viewModel.totalCards) cards")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var summaryCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                SummaryCardView(title: "Investment", value: "$\(formatted(viewModel.totalInvestment))",
                    icon: "dollarsign.circle.fill", color: .blue, subtitle: "Total invested")
                SummaryCardView(title: "Profit", value: "$\(formatted(viewModel.totalProfit))",
                    icon: viewModel.totalProfit >= 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                    color: viewModel.totalProfit >= 0 ? .green : .red,
                    subtitle: viewModel.totalProfit >= 0 ? "Net gain" : "Net loss")
            }
            HStack(spacing: 12) {
                SummaryCardView(title: "PSA", value: "\(viewModel.psaCount)",
                    icon: "shield.checkered", color: .orange, subtitle: "Graded cards")
                SummaryCardView(title: "Raw", value: "\(viewModel.nonPSACount)",
                    icon: "rectangle.on.rectangle.angled", color: .purple, subtitle: "Ungraded cards")
            }
        }
    }

    private var detailSections: some View {
        VStack(spacing: 16) {
            DetailSectionView(title: "Portfolio", icon: "chart.pie.fill", tint: .blue) {
                VStack(spacing: 10) {
                    DetailRowView(label: "Entries", value: "\(viewModel.totalEntries)")
                    DetailRowView(label: "Total Cards", value: "\(viewModel.totalCards)")
                    DetailRowView(label: "Total Investment", value: "$\(formatted(viewModel.totalInvestment))")
                    if viewModel.soldCount > 0 {
                        DetailRowView(label: "Realized Profit", value: "$\(formatted(viewModel.totalProfit))",
                            valueColor: viewModel.totalProfit >= 0 ? .green : .red)
                    }
                    DetailRowView(label: "Sold", value: "\(viewModel.soldCount)")
                    DetailRowView(label: "Holding", value: "\(viewModel.unsoldCount)")
                }
            }
        }
    }

    private func formatted(_ value: Double) -> String {
        if abs(value) >= 1000 { return String(format: "%.0f", value) }
        return String(format: "%.2f", value)
    }
}

struct SummaryCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(color).symbolRenderingMode(.hierarchical)
            Spacer()
            Text(value).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(.primary)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct DetailSectionView<Content: View>: View {
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct DetailRowView: View {
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
