//
//  DashboardViewModel.swift
//  Balance
//
//  Created by Eduardo Flores on 02/07/26.
//

import Foundation

struct DashboardViewModel {
	let accounts: [Account]
	let transactions: [Transaction]

	var netWorth: Double {
		accounts.reduce(0) { $0 + $1.balance }
	}

	var totalAssets: Double {
		accounts.reduce(0) { partialResult, account in
			partialResult + max(0, account.balance)
		}
	}

	var totalLiabilities: Double {
		accounts.reduce(0) { partialResult, account in
			partialResult + abs(min(0, account.balance))
		}
	}

	var categoryBalances: [DashboardCategoryBalanceSummary] {
		let totalsByCategory = Dictionary(grouping: accounts, by: \.category)
			.mapValues { categoryAccounts in
				categoryAccounts.reduce(0) { $0 + $1.balance }
			}

		return totalsByCategory
			.map { DashboardCategoryBalanceSummary(category: $0.key, totalBalance: $0.value) }
			.sorted { $0.totalBalance > $1.totalBalance }
	}

	var last30DayFlow: [DashboardDailyFlowSummary] {
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

		var summaries: [DashboardDailyFlowSummary] = []
		for offset in 0..<30 {
			guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
			let values = valuesByDay[date] ?? (0, 0)
			summaries.append(DashboardDailyFlowSummary(date: date, income: values.income, expense: values.expense))
		}

		return summaries
	}
}
