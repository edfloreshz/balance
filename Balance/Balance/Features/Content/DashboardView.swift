import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
	struct CategoryBalanceSummary: Identifiable {
		let category: Category
		let totalBalance: Double
		
		var id: Category { category }
	}
	
	struct DailyFlowSummary: Identifiable {
		let date: Date
		let income: Double
		let expense: Double
		
		var id: Date { date }
	}
	
	@Query(sort: \Account.name) private var accounts: [Account]
	@Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
	
	private var netWorth: Double {
		accounts.reduce(0) { $0 + $1.balance }
	}
	
	private var totalAssets: Double {
		accounts.reduce(0) { partialResult, account in
			partialResult + max(0, account.balance)
		}
	}
	
	private var totalLiabilities: Double {
		accounts.reduce(0) { partialResult, account in
			partialResult + abs(min(0, account.balance))
		}
	}
	
	private var categoryBalances: [CategoryBalanceSummary] {
		let totalsByCategory = Dictionary(grouping: accounts, by: \.category)
			.mapValues { categoryAccounts in
				categoryAccounts.reduce(0) { $0 + $1.balance }
			}
		
		return totalsByCategory
			.map { CategoryBalanceSummary(category: $0.key, totalBalance: $0.value) }
			.sorted { $0.totalBalance > $1.totalBalance }
	}
	
	private var last30DayFlow: [DailyFlowSummary] {
		var calendar = Calendar.autoupdatingCurrent
		calendar.timeZone = .autoupdatingCurrent
		
		let endDate = calendar.startOfDay(for: .now)
		guard let startDate = calendar.date(byAdding: .day, value: -29, to: endDate) else {
			return []
		}
		
		let rangeTransactions = transactions.filter { transaction in
			!transaction.isRecurringTemplate
			&& transaction.date >= startDate
			&& transaction.date <= endDate
		}
		
		var valuesByDay: [Date: (income: Double, expense: Double)] = [:]
		for transaction in rangeTransactions {
			let day = calendar.startOfDay(for: transaction.date)
			var values = valuesByDay[day] ?? (0, 0)
			switch transaction.type {
			case .income:
				values.income += abs(transaction.amount)
			case .expense:
				values.expense += abs(transaction.amount)
			case .transferOut, .transferIn:
				continue
			}
			valuesByDay[day] = values
		}
		
		var summaries: [DailyFlowSummary] = []
		for offset in 0..<30 {
			guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
			let values = valuesByDay[date] ?? (0, 0)
			summaries.append(DailyFlowSummary(date: date, income: values.income, expense: values.expense))
		}
		
		return summaries
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
	}
	
	private var summaryCards: some View {
		LazyVGrid(
			columns: [
				GridItem(.adaptive(minimum: 180), spacing: 12)
			],
			spacing: 12
		) {
			metricCard("Net Worth", value: netWorth, accent: netWorth >= 0 ? .green : .red)
			metricCard("Assets", value: totalAssets, accent: .blue)
			metricCard("Liabilities", value: totalLiabilities, accent: .orange)
			metricCard("Accounts", textValue: "\(accounts.count)", accent: .purple)
		}
	}
	
	private var categoryChart: some View {
		GroupBox("Balance by Category") {
			Chart(categoryBalances) { summary in
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
			Chart(last30DayFlow) { summary in
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
	
	@ViewBuilder
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
