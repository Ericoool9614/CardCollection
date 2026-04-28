import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                heroSection
                statsGrid
                investmentSection
                languageBreakdown
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("卡库")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { viewModel.loadDashboard() }
        .refreshable { viewModel.loadDashboard() }
    }

    private var heroSection: some View {
        VStack(spacing: 4) {
            Text("\(viewModel.totalEntries)")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("个收藏条目")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "总卡牌", value: "\(viewModel.totalCards)",
                icon: "rectangle.on.rectangle.angled", color: .blue)
            StatCard(title: "评级卡", value: "\(viewModel.psaCount)",
                icon: "shield.checkered", color: .orange)
            StatCard(title: "裸卡", value: "\(viewModel.nonPSACount)",
                icon: "rectangle.on.rectangle.angled", color: .purple)
            StatCard(title: "已出售", value: "\(viewModel.soldCount)",
                icon: "tag.fill", color: .green)
        }
    }

    private var investmentSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(.blue)
                    .font(.subheadline.weight(.semibold))
                Text("投资概览")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 12)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("总投入")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.formatted(viewModel.totalInvestment))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("已实现盈亏")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.formatted(viewModel.totalProfit))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(viewModel.totalProfit >= 0 ? .green : .red)
                }
            }

            if viewModel.soldCount > 0 {
                Divider()
                    .padding(.vertical, 10)

                HStack {
                    Text("持有中 \(viewModel.unsoldCount) 个条目")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("已出售 \(viewModel.soldCount) 个条目")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var languageBreakdown: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .foregroundStyle(.indigo)
                    .font(.subheadline.weight(.semibold))
                Text("语言分布")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 12)

            if viewModel.languageCounts.isEmpty {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(Array(viewModel.languageCounts.sorted { $0.value > $1.value }), id: \.key) { lang, count in
                    HStack {
                        Text(lang)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(count)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)
            Spacer()
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
