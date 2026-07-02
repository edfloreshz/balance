import Foundation
import SwiftData

enum RecurringTransactionProcessor {
	@MainActor
	static func processDueTransactions(
		context: ModelContext,
		recurringTransactions: [Transaction],
		until date: Date,
		calendar: Calendar
	) throws {
		for recurring in recurringTransactions {
			try process(recurring: recurring, context: context, until: date, calendar: calendar)
		}
		
		try context.save()
	}
	
	@MainActor
	private static func process(
		recurring: Transaction,
		context: ModelContext,
		until now: Date,
		calendar: Calendar
	) throws {
		var occurrenceDate = recurring.nextOccurrenceDate
		let amount = abs(recurring.amount)
		
		while occurrenceDate <= now {
			if let endDate = recurring.endDate, occurrenceDate > endDate {
				break
			}
			
			try createTransactionOccurrence(
				for: recurring,
				on: occurrenceDate,
				amount: amount,
				context: context
			)
			
			guard let nextDate = nextOccurrenceDate(
				after: occurrenceDate,
				frequency: recurring.frequency,
				calendar: calendar
			) else {
				break
			}
			occurrenceDate = nextDate
		}
		
		recurring.nextOccurrenceDate = occurrenceDate
	}
	
	@MainActor
	private static func createTransactionOccurrence(
		for recurring: Transaction,
		on date: Date,
		amount: Double,
		context: ModelContext
	) throws {
		guard let sourceAccount = recurring.account else {
			throw NSError(
				domain: "RecurringTransactionProcessor",
				code: 1,
				userInfo: [NSLocalizedDescriptionKey: "Recurring transaction has no source account."]
			)
		}
		
		let recurrenceEndDate = recurring.endDate
		
		switch recurring.type {
		case .expense:
			let transaction = Transaction(
				amount: -amount,
				note: recurring.note,
				date: date,
				type: .expense,
				recurrenceFrequency: recurring.frequency,
				recurrenceSeriesID: recurring.id,
				recurrenceStartDate: recurring.startDate,
				recurrenceEndDate: recurrenceEndDate,
				account: sourceAccount
			)
			context.insert(transaction)
			sourceAccount.balance -= amount
		case .income:
			let transaction = Transaction(
				amount: amount,
				note: recurring.note,
				date: date,
				type: .income,
				recurrenceFrequency: recurring.frequency,
				recurrenceSeriesID: recurring.id,
				recurrenceStartDate: recurring.startDate,
				recurrenceEndDate: recurrenceEndDate,
				account: sourceAccount
			)
			context.insert(transaction)
			sourceAccount.balance += amount
		case .transferOut:
			guard let destinationAccount = recurring.relatedAccount else {
				throw NSError(
					domain: "RecurringTransactionProcessor",
					code: 2,
					userInfo: [NSLocalizedDescriptionKey: "Recurring transfer has no destination account."]
				)
			}
			
			let transferGroupID = UUID()
			let sourceTransaction = Transaction(
				amount: -amount,
				note: recurring.note,
				date: date,
				type: .transferOut,
				transferGroupID: transferGroupID,
				recurrenceFrequency: recurring.frequency,
				recurrenceSeriesID: recurring.id,
				recurrenceStartDate: recurring.startDate,
				recurrenceEndDate: recurrenceEndDate,
				account: sourceAccount,
				relatedAccount: destinationAccount
			)
			let destinationTransaction = Transaction(
				amount: amount,
				note: recurring.note,
				date: date,
				type: .transferIn,
				transferGroupID: transferGroupID,
				recurrenceFrequency: recurring.frequency,
				recurrenceSeriesID: recurring.id,
				recurrenceStartDate: recurring.startDate,
				recurrenceEndDate: recurrenceEndDate,
				account: destinationAccount,
				relatedAccount: sourceAccount
			)
			context.insert(sourceTransaction)
			context.insert(destinationTransaction)
			sourceAccount.balance -= amount
			destinationAccount.balance += amount
		case .transferIn:
			break
		}
	}
	
	private static func nextOccurrenceDate(
		after date: Date,
		frequency: RecurrenceFrequency,
		calendar: Calendar
	) -> Date? {
		switch frequency {
		case .daily:
			return calendar.date(byAdding: .day, value: 1, to: date)
		case .weekly:
			return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
		case .monthly:
			return calendar.date(byAdding: .month, value: 1, to: date)
		case .yearly:
			return calendar.date(byAdding: .year, value: 1, to: date)
		}
	}
}
