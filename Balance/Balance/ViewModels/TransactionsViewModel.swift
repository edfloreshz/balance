import Foundation
import Observation

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

enum AddTransactionMode: String, Identifiable {
	case oneTime
	case recurring

	var id: String { rawValue }
}

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

	var mode: TransactionsListView.Mode {
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
