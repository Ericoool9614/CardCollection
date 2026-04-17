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
        .navigationTitle("收藏概览")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { viewModel.loadDashboard() }
        .refreshable { viewModel.loadDashboard() }
    }

    private var heroSection: some View {
        VStack(spacing: 6) {
            Text("宝可梦卡牌")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("\(viewModel.totalEntries) 个条目，\(viewModel.totalCards) 张卡牌")
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
                SummaryCardView(title: "投入", value: viewModel.formatted(viewModel.totalInvestment),
                    icon: "yensign.circle.fill", color: .blue, subtitle: "总投入金额")
                SummaryCardView(title: "盈亏", value: viewModel.formatted(viewModel.totalProfit),
                    icon: viewModel.totalProfit >= 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                    color: viewModel.totalProfit >= 0 ? .green : .red,
                    subtitle: viewModel.totalProfit >= 0 ? "净盈利" : "净亏损")
            }
            HStack(spacing: 12) {
                SummaryCardView(title: "评级卡", value: "\(viewModel.psaCount)",
                    icon: "shield.checkered", color: .orange, subtitle: "已评级卡牌")
                SummaryCardView(title: "裸卡", value: "\(viewModel.nonPSACount)",
                    icon: "rectangle.on.rectangle.angled", color: .purple, subtitle: "未评级卡牌")
            }
        }
    }

    private var detailSections: some View {
        VStack(spacing: 16) {
            DetailSectionView(title: "投资组合", icon: "chart.pie.fill", tint: .blue) {
                VStack(spacing: 10) {
                    DetailRowView(label: "条目数", value: "\(viewModel.totalEntries)")
                    DetailRowView(label: "卡牌总数", value: "\(viewModel.totalCards)")
                    DetailRowView(label: "总投入", value: viewModel.formatted(viewModel.totalInvestment))
                    if viewModel.soldCount > 0 {
                        DetailRowView(label: "已实现盈亏", value: viewModel.formatted(viewModel.totalProfit),
                            valueColor: viewModel.totalProfit >= 0 ? .green : .red)
                    }
                    DetailRowView(label: "已出售", value: "\(viewModel.soldCount)")
                    DetailRowView(label: "持有中", value: "\(viewModel.unsoldCount)")
                }
            }
        }
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
