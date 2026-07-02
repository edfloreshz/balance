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

@Model class Transaction {
	@Attribute(.unique) var id: UUID = UUID()
	var amount: Double
	var note: String
	var date: Date
	var typeRawValue: String
	var transferGroupID: UUID?
	var account: Account?
	var relatedAccount: Account?
	
	var type: TransactionKind {
		get { TransactionKind(rawValue: typeRawValue) ?? .expense }
		set { typeRawValue = newValue.rawValue }
	}
	
	init(
		id: UUID = UUID(),
		amount: Double,
		note: String = "",
		date: Date = .now,
		type: TransactionKind? = nil,
		transferGroupID: UUID? = nil,
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
		self.account = account
		self.relatedAccount = relatedAccount
	}
}
