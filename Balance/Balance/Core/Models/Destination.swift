//
//  Destination.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

enum Destination: Hashable {
	case category(Category)
	case account(Account)
	
	func hash(into hasher: inout Hasher) {
		switch self {
		case .category(let category):
			hasher.combine("category")
			hasher.combine(category.id)
		case .account(let account):
			hasher.combine("account")
			hasher.combine(account.id)
		}
	}
	
	static func == (lhs: Destination, rhs: Destination) -> Bool {
		switch (lhs, rhs) {
		case (.account(let lAccount), .account(let rAccount)):
			return lAccount.id == rAccount.id
		default:
			return false
		}
	}
}
