//
//  Account.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//
import Foundation
import SwiftData

@Model class Account {
	@Attribute(.unique) var id: UUID = UUID()
	var name: String
	var icon: String
	var categoryRawValue: String
	var balance: Double
	var currency: String
	var createdAt: Date
	var isArchived: Bool
	var colorTag: String?
	
	@Relationship(deleteRule: .cascade, inverse: \Transaction.account)
	var transactions: [Transaction] = []
	
	var category: Category {
		get { Category(rawValue: categoryRawValue) ?? .checking }
		set { categoryRawValue = newValue.rawValue }
	}
	
	init(
		id: UUID = UUID(),
		name: String,
		icon: String = "",
		category: Category,
		balance: Double = 0,
		currency: String = "USD",
		createdAt: Date = .now,
		isArchived: Bool = false,
		colorTag: String? = nil
	) {
		self.id = id
		self.name = name
		self.icon = icon
		self.categoryRawValue = category.rawValue
		self.balance = balance
		self.currency = currency
		self.createdAt = createdAt
		self.isArchived = isArchived
		self.colorTag = colorTag
	}
}
