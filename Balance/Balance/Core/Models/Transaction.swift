//
//  Transaction.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import Foundation
import SwiftData

enum TransactionKind: String, Codable, CaseIterable, Identifiable {
	case expense
	case income
	case transferOut
	case transferIn
	
	var id: Self { self }
	
	var displayName: String {
		switch self {
		case .expense: return "Expense"
		case .income: return "Income"
		case .transferOut: return "Transfer"
		case .transferIn: return "Transfer In"
		}
	}
}

enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
	case daily
	case weekly
	case monthly
	case yearly
	
	var id: Self { self }
	
	var displayName: String {
		switch self {
		case .daily: return "Daily"
		case .weekly: return "Weekly"
		case .monthly: return "Monthly"
		case .yearly: return "Yearly"
		}
	}
}

protocol TransactionRepresentable {
	var amount: Double { get }
	var note: String { get }
	var type: TransactionKind { get }
	var account: Account? { get }
	var relatedAccount: Account? { get }
}

extension TransactionRepresentable {
	var signedAmount: Double {
		switch type {
		case .expense, .transferOut:
			return -abs(amount)
		case .income, .transferIn:
			return abs(amount)
		}
	}
}

@Model class Transaction {
	@Attribute(.unique) var id: UUID = UUID()
	var amount: Double
	var note: String
	var date: Date
	var typeRawValue: String
	var transferGroupID: UUID?
	var recurrenceFrequencyRawValue: String?
	var recurrenceSeriesID: UUID?
	var recurrenceStartDate: Date?
	var recurrenceEndDate: Date?
	var recurrenceNextOccurrenceDate: Date?
	var account: Account?
	var relatedAccount: Account?
	
	var type: TransactionKind {
		get { TransactionKind(rawValue: typeRawValue) ?? .expense }
		set { typeRawValue = newValue.rawValue }
	}
	
	var recurrenceFrequency: RecurrenceFrequency? {
		get {
			guard let recurrenceFrequencyRawValue else { return nil }
			return RecurrenceFrequency(rawValue: recurrenceFrequencyRawValue)
		}
		set { recurrenceFrequencyRawValue = newValue?.rawValue }
	}

	var frequency: RecurrenceFrequency {
		get { recurrenceFrequency ?? .monthly }
		set { recurrenceFrequency = newValue }
	}

	var startDate: Date {
		get { recurrenceStartDate ?? date }
		set { recurrenceStartDate = newValue }
	}

	var endDate: Date? {
		get { recurrenceEndDate }
		set { recurrenceEndDate = newValue }
	}

	var nextOccurrenceDate: Date {
		get { recurrenceNextOccurrenceDate ?? startDate }
		set { recurrenceNextOccurrenceDate = newValue }
	}

	var isRecurringTemplate: Bool {
		recurrenceFrequencyRawValue != nil && recurrenceSeriesID == nil
	}
	
	init(
		id: UUID = UUID(),
		amount: Double,
		note: String = "",
		date: Date = .now,
		type: TransactionKind? = nil,
		transferGroupID: UUID? = nil,
		recurrenceFrequency: RecurrenceFrequency? = nil,
		recurrenceSeriesID: UUID? = nil,
		recurrenceStartDate: Date? = nil,
		recurrenceEndDate: Date? = nil,
		recurrenceNextOccurrenceDate: Date? = nil,
		account: Account? = nil,
		relatedAccount: Account? = nil
	) {
		self.id = id
		self.amount = amount
		self.note = note
		self.date = date
		let inferredType: TransactionKind = type ?? (amount >= 0 ? .income : .expense)
		self.typeRawValue = inferredType.rawValue
		self.transferGroupID = transferGroupID
		self.recurrenceFrequencyRawValue = recurrenceFrequency?.rawValue
		self.recurrenceSeriesID = recurrenceSeriesID
		self.recurrenceStartDate = recurrenceStartDate
		self.recurrenceEndDate = recurrenceEndDate
		self.recurrenceNextOccurrenceDate = recurrenceNextOccurrenceDate
		self.account = account
		self.relatedAccount = relatedAccount
	}

	convenience init(
		id: UUID = UUID(),
		amount: Double,
		note: String = "",
		type: TransactionKind,
		frequency: RecurrenceFrequency,
		startDate: Date,
		endDate: Date? = nil,
		nextOccurrenceDate: Date? = nil,
		account: Account? = nil,
		relatedAccount: Account? = nil
	) {
		self.init(
			id: id,
			amount: amount,
			note: note,
			date: startDate,
			type: type,
			recurrenceFrequency: frequency,
			recurrenceStartDate: startDate,
			recurrenceEndDate: endDate,
			recurrenceNextOccurrenceDate: nextOccurrenceDate ?? startDate,
			account: account,
			relatedAccount: relatedAccount
		)
	}
}

extension Transaction: TransactionRepresentable {}

/// Everything a row needs to render a transaction from the perspective of
/// a particular account, with direction/amount/labels already resolved.
///
/// For a plain expense/income this is identical to the transaction's own
/// values. For a transfer (send or request), viewing it from the
/// `relatedAccount` side flips the type and sign so a "Request" template
/// reads as incoming money on the receiving account and outgoing money on
/// the paying account, even though both share the same underlying rows.
struct TransactionDisplayContext {
	let type: TransactionKind
	let signedAmount: Double
	let primaryAccountName: String
	let counterpartyName: String?
}

extension Transaction {
	func displayContext(for viewingAccountID: UUID) -> TransactionDisplayContext {
		let viewedFromRelatedSide = account?.id != viewingAccountID && relatedAccount?.id == viewingAccountID

		let resolvedType: TransactionKind = {
			guard viewedFromRelatedSide else { return type }
			switch type {
			case .transferOut: return .transferIn
			case .transferIn: return .transferOut
			case .expense, .income: return type
			}
		}()

		return TransactionDisplayContext(
			type: resolvedType,
			signedAmount: viewedFromRelatedSide ? -signedAmount : signedAmount,
			primaryAccountName: (viewedFromRelatedSide ? relatedAccount?.name : account?.name) ?? "Unassigned",
			counterpartyName: viewedFromRelatedSide ? account?.name : relatedAccount?.name
		)
	}
}

