//
//  Transaction+SampleData.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import Foundation

extension Transaction {
	/// Generates sample transactions for a given set of accounts.
	/// Pass in `Account.sampleData` (already inserted into a context) so each
	/// transaction can be linked to a real `Account` instance.
	static func sampleData(for accounts: [Account]) -> [Transaction] {
		guard let bbva = accounts.first(where: { $0.name == "BBVA" }),
			  let bbvaOro = accounts.first(where: { $0.name == "BBVA Oro" }),
			  let banamex = accounts.first(where: { $0.name == "Banamex" }),
			  let liverpool = accounts.first(where: { $0.name == "Liverpool" }),
			  let sears = accounts.first(where: { $0.name == "Sears" }),
			  let crypto = accounts.first(where: { $0.name == "Crypto" })
		else {
			return []
		}
		
		let calendar = Calendar.current
		func daysAgo(_ days: Int, hour: Int = 12) -> Date {
			let base = calendar.date(byAdding: .day, value: -days, to: .now) ?? .now
			return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base
		}
		
		return [
			// BBVA (savings)
			Transaction(amount: 15000, note: "Payroll deposit", date: daysAgo(1, hour: 9), account: bbva),
			Transaction(amount: -450.50, note: "Groceries - Soriana", date: daysAgo(2, hour: 18), account: bbva),
			Transaction(amount: -120, note: "Netflix", date: daysAgo(3, hour: 8), account: bbva),
			Transaction(amount: -1200, note: "Rent transfer", date: daysAgo(5, hour: 10), account: bbva),
			Transaction(amount: 500, note: "Refund - Amazon", date: daysAgo(7, hour: 14), account: bbva),
			
			// BBVA Oro (credit card)
			Transaction(amount: -899, note: "Restaurant - La Parrilla", date: daysAgo(1, hour: 21), account: bbvaOro),
			Transaction(amount: -239.99, note: "Spotify Family", date: daysAgo(4, hour: 11), account: bbvaOro),
			Transaction(amount: -1500, note: "Gasoline", date: daysAgo(6, hour: 17), account: bbvaOro),
			Transaction(amount: 2000, note: "Payment received", date: daysAgo(10, hour: 12), account: bbvaOro),
			
			// Banamex (credit card)
			Transaction(amount: -320, note: "Uber rides", date: daysAgo(2, hour: 19), account: banamex),
			Transaction(amount: -1899, note: "Flight - Aeromexico", date: daysAgo(8, hour: 13), account: banamex),
			Transaction(amount: -75, note: "Coffee - Starbucks", date: daysAgo(9, hour: 8), account: banamex),
			
			// Liverpool (store card)
			Transaction(amount: -2499, note: "New shoes", date: daysAgo(3, hour: 16), account: liverpool),
			Transaction(amount: -899, note: "Home decor", date: daysAgo(12, hour: 15), account: liverpool),
			
			// Sears (store card)
			Transaction(amount: -1599, note: "Appliance repair", date: daysAgo(5, hour: 10), account: sears),
			Transaction(amount: 300, note: "Store credit refund", date: daysAgo(15, hour: 12), account: sears),
			
			// Crypto (investment)
			Transaction(amount: 5000, note: "BTC purchase", date: daysAgo(4, hour: 12), account: crypto),
			Transaction(amount: -800, note: "ETH sale", date: daysAgo(6, hour: 12), account: crypto),
			Transaction(amount: 1250, note: "Portfolio gain", date: daysAgo(14, hour: 12), account: crypto)
		]
	}
}
