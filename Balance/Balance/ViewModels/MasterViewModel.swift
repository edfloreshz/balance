import Observation

@Observable
final class MasterViewModel {
	var selectedCategory: Category = .savings
	var sidebarSelection: SidebarSelection = .category(.savings)
	var selectedAccount: Account?
	var accountSearchText: String = ""
	var transactionSearchText: String = ""
	var showingAddAccount = false
	var showingAddTransaction = false
	var showingSettings = false
	var addTransactionInitialKind: TransactionKind = .expense
	var recurringSyncErrorMessage: String?
	var accountDeletionErrorMessage: String?
	var showingDeleteAccountConfirmation = false
	var showingEditAccount = false

	var searchPrompt: String {
		selectedAccount == nil ? "Search accounts" : "Search transactions"
	}

	var activeSearchText: String {
		get { selectedAccount == nil ? accountSearchText : transactionSearchText }
		set {
			if selectedAccount == nil {
				accountSearchText = newValue
			} else {
				transactionSearchText = newValue
			}
		}
	}

	func synchronizeSidebarSelectionWithCategory() {
		if case .category = sidebarSelection {
			sidebarSelection = .category(selectedCategory)
		}
	}

	func handleSidebarSelectionChange() {
		switch sidebarSelection {
		case .dashboard:
			selectedAccount = nil
		case .category(let category):
			selectedCategory = category
		}
	}

	func handleAccountCreated(_ account: Account) {
		selectedCategory = account.category
		sidebarSelection = .category(account.category)
		selectedAccount = account
	}

	func showAddTransaction(initialKind: TransactionKind) {
		addTransactionInitialKind = initialKind
		showingAddTransaction = selectedAccount != nil
	}

	func requestSelectedAccountDeletion() {
		showingDeleteAccountConfirmation = selectedAccount != nil
	}
}
