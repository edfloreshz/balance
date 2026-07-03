import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
	@Query(sort: \Account.name) private var accounts: [Account]
	@Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

	private var viewModel: DashboardViewModel {
		DashboardViewModel(accounts: accounts, transactions: transactions)
	}
	
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				if accounts.isEmpty {
					ContentUnavailableView(
						"Dashboard",
						systemImage: "chart.xyaxis.line",
						description: Text("Add accounts to see your financial overview.")
					)
				} else {
					summaryCards
					categoryChart
					flowChart
				}
			}
			.padding(16)
		}
		.navigationTitle("Dashboard")
#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
	}
	
	private var summaryCards: some View {
		LazyVGrid(
			columns: [
				GridItem(.adaptive(minimum: 180), spacing: 12)
			],
			spacing: 12
		) {
			metricCard("Net Worth", value: viewModel.netWorth, accent: viewModel.netWorth >= 0 ? .green : .red)
			metricCard("Assets", value: viewModel.totalAssets, accent: .blue)
			metricCard("Liabilities", value: viewModel.totalLiabilities, accent: .orange)
			metricCard("Accounts", textValue: "\(accounts.count)", accent: .purple)
		}
	}
	
	private var categoryChart: some View {
		GroupBox("Balance by Category") {
			Chart(viewModel.categoryBalances) { summary in
				BarMark(
					x: .value("Category", summary.category.name),
					y: .value("Balance", summary.totalBalance)
				)
				.foregroundStyle(summary.category.color.gradient)
			}
			.frame(minHeight: 220)
		}
	}
	
	private var flowChart: some View {
		GroupBox("Income vs Expense (30 days)") {
			Chart(viewModel.last30DayFlow) { summary in
				LineMark(
					x: .value("Day", summary.date),
					y: .value("Income", summary.income)
				)
				.foregroundStyle(.green)
				.interpolationMethod(.catmullRom)
				
				LineMark(
					x: .value("Day", summary.date),
					y: .value("Expense", summary.expense)
				)
				.foregroundStyle(.red)
				.interpolationMethod(.catmullRom)
			}
			.frame(minHeight: 220)
		}
	}
	
	private func metricCard(_ title: String, value: Double? = nil, textValue: String? = nil, accent: Color) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(title)
				.font(.caption.weight(.medium))
				.foregroundStyle(.secondary)
			
			if let value {
				Text(value, format: .currency(code: AppPreferences.defaultGlobalCurrencyCode))
					.font(.title3.weight(.semibold))
					.foregroundStyle(accent)
			} else {
				Text(textValue ?? "—")
					.font(.title3.weight(.semibold))
					.foregroundStyle(accent)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(12)
		.background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
	}
}

#Preview {
	NavigationStack {
		DashboardView()
	}
	.modelContainer(PreviewData.shared.modelContainer)
}
