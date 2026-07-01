//
//  Transaction.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import Foundation
import SwiftData

@Model class Transaction {
	@Attribute(.unique) var id: UUID = UUID()
	var amount: Double
	var note: String
	var date: Date
	var account: Account?
	
	init(id: UUID = UUID(), amount: Double, note: String = "", date: Date = .now, account: Account? = nil) {
		self.id = id
		self.amount = amount
		self.note = note
		self.date = date
		self.account = account
	}
}
