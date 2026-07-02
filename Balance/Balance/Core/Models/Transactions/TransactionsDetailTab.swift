//
//  TransactionsDetailTab.swift
//  Balance
//
//  Created by Eduardo Flores on 02/07/26.
//

enum TransactionsDetailTab: String, CaseIterable, Identifiable {
	case transactions
	case recurring
	
	var id: Self { self }
	
	var title: String {
		switch self {
		case .transactions: return "Transactions"
		case .recurring: return "Recurring"
		}
	}
}
