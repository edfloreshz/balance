//
//  TransactionsViewModel.swift
//  Balance
//
//  Created by Eduardo Flores on 02/07/26.
//

import Foundation
import Observation

@Observable
final class TransactionsViewModel {
	var searchText: String = ""
	var addTransactionMode: AddTransactionMode?
	var saveErrorMessage: String?
	var selectedTab: TransactionsDetailTab = .transactions
	var expandedTransactionIDs: Set<UUID> = []
	var selectedTransactionIDs: Set<UUID> = []
	var showingDeleteTransactionsConfirmation = false
	var editingTransaction: Transaction?

	var mode: TransactionListView.Mode {
		selectedTab == .transactions ? .transactions : .recurring
	}

	var showingAddTransaction: Bool {
		get { addTransactionMode != nil }
		set {
			if !newValue {
				addTransactionMode = nil
			} else if addTransactionMode == nil {
				addTransactionMode = .oneTime
			}
		}
	}

	var startsAsRecurring: Bool {
		get { addTransactionMode == .recurring }
		set { addTransactionMode = newValue ? .recurring : .oneTime }
	}

	var canEditSelectedTransaction: Bool {
		selectedTransactionIDs.count == 1
	}

	func retainSelectedTransactionIDs(visibleIDs: [UUID]) {
		selectedTransactionIDs = selectedTransactionIDs.intersection(Set(visibleIDs))
	}
}
