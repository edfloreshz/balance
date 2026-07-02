import SwiftData
import SwiftUI

struct RecurringTransactionsView: View {
	@Query private var recurringTransactions: [Transaction]
	@AppStorage(AppPreferences.usesAutomaticTimeZoneKey) private var usesAutomaticTimeZone: Bool = true
	@AppStorage(AppPreferences.selectedTimeZoneIdentifierKey) private var selectedTimeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier
	private let searchText: String
	@Binding var showingAddTransaction: Bool
	@Binding var startsAsRecurring: Bool
	@Binding var saveErrorMessage: String?
	@State private var expandedTransactionIDs: Set<UUID> = []
	
	init(
		account: Account,
		searchText: String = "",
		showingAddTransaction: Binding<Bool>,
		startsAsRecurring: Binding<Bool>,
		saveErrorMessage: Binding<String?>
	) {
		self.searchText = searchText
		self._showingAddTransaction = showingAddTransaction
		self._startsAsRecurring = startsAsRecurring
		self._saveErrorMessage = saveErrorMessage
		let accountID = account.id
		let predicate = #Predicate<Transaction> { transaction in
			transaction.account?.id == accountID
			&& transaction.recurrenceFrequencyRawValue != nil
			&& transaction.recurrenceSeriesID == nil
		}
		_recurringTransactions = Query(filter: predicate, sort: \.date, order: .reverse)
	}
	
	private var timeZone: TimeZone {
		AppPreferences.effectiveTimeZone(
			usesAutomaticTimeZone: usesAutomaticTimeZone,
			selectedTimeZoneIdentifier: selectedTimeZoneIdentifier
		)
	}
	
	private var filteredRecurringTransactions: [Transaction] {
		let source: [Transaction]
		if searchText.isEmpty {
			source = recurringTransactions
		} else {
			source = recurringTransactions.filter { recurring in
				let searchable = [
					recurring.note,
					recurring.type.displayName,
					recurring.frequency.displayName,
					recurring.account?.name ?? "",
					recurring.relatedAccount?.name ?? ""
				].joined(separator: " ")
				return searchable.localizedCaseInsensitiveContains(searchText)
			}
		}

		return source.sorted { $0.nextOccurrenceDate < $1.nextOccurrenceDate }
	}
	
	var body: some View {
		if filteredRecurringTransactions.isEmpty {
			if searchText.isEmpty {
				emptyState
			} else {
				ContentUnavailableView.search(text: searchText)
			}
		} else {
			List {
				ForEach(filteredRecurringTransactions) { recurring in
					TransactionRow(
						transaction: recurring,
						isExpanded: binding(for: recurring),
						timeZone: timeZone
					)
				}
			}
			.listStyle(.plain)
		}
	}
	
	private var emptyState: some View {
		VStack(spacing: 12) {
			Spacer()
			if searchText.isEmpty {
				Image(systemName: "repeat")
					.font(.system(size: 40))
					.foregroundStyle(.tertiary)
				Text("Recurring Transactions")
					.font(.headline)
					.foregroundStyle(.secondary)
				Text("Recurring transactions for this account will appear here.")
					.font(.subheadline)
					.foregroundStyle(.tertiary)
				
				Button("Add Recurrent Transaction") {
					startsAsRecurring = true
					showingAddTransaction = true
				}
				.buttonStyle(.borderedProminent)
			} else {
				ContentUnavailableView.search(text: searchText)
			}
			Spacer()
		}
		.frame(maxWidth: .infinity)
	}
	
	private func binding(for transaction: Transaction) -> Binding<Bool> {
		Binding(
			get: { expandedTransactionIDs.contains(transaction.id) },
			set: { isExpanded in
				if isExpanded {
					expandedTransactionIDs.insert(transaction.id)
				} else {
					expandedTransactionIDs.remove(transaction.id)
				}
			}
		)
	}
}

#Preview {
	RecurringTransactionsView(
		account: Account(name: "Chase Checking", category: .checking),
		searchText: "",
		showingAddTransaction: .constant(false),
		startsAsRecurring: .constant(false),
		saveErrorMessage: .constant("")
	)
	.modelContainer(PreviewData.shared.modelContainer)
}
