//
//  TransactionsContentView.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import SwiftData
import SwiftUI

struct TransactionsListView: View {
	@Bindable var account: Account
	@Binding var searchText: String
	@Binding var showingAddTransaction: Bool
	@Binding var startsAsRecurring: Bool
	@Binding var saveErrorMessage: String?
	
	@Environment(\.modelContext) private var modelContext
	@Environment(\.timeZone) private var timeZone
	@Query private var transactions: [Transaction]
	@Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
	@State private var expandedTransactionIDs: Set<UUID> = []
	
	init(
		account: Account,
		searchText: Binding<String>,
		showingAddTransaction: Binding<Bool>,
		startsAsRecurring: Binding<Bool>,
		saveErrorMessage: Binding<String?>
	) {
		self.account = account
		self._searchText = searchText
		self._showingAddTransaction = showingAddTransaction
		self._startsAsRecurring = startsAsRecurring
		self._saveErrorMessage = saveErrorMessage
		let accountID = account.id
		
		let predicate = #Predicate<Transaction> { transaction in
			transaction.account?.id == accountID
			&& (transaction.recurrenceFrequencyRawValue == nil || transaction.recurrenceSeriesID != nil)
		}
		
		_transactions = Query(filter: predicate, sort: \.date, order: .reverse)
	}
	
	private var filteredTransactions: [Transaction] {
		guard !searchText.isEmpty else { return transactions }
		return transactions.filter {
			$0.note.localizedCaseInsensitiveContains(searchText)
		}
	}
	
	private var groupedTransactions: [(date: Date, items: [Transaction])] {
		let groups = Dictionary(grouping: filteredTransactions) { transaction in
			calendar.startOfDay(for: transaction.date)
		}
		return groups
			.map { (date: $0.key, items: $0.value) }
			.sorted { $0.date > $1.date }
	}
	
	private var calendar: Calendar {
		var calendar = Calendar.autoupdatingCurrent
		calendar.timeZone = timeZone
		return calendar
	}
	
	var body: some View {
		if filteredTransactions.isEmpty {
			emptyState
		} else {
			List {
				ForEach(groupedTransactions, id: \.date) { group in
					Section {
						ForEach(group.items) { transaction in
							TransactionRow(
								transaction: transaction,
								isExpanded: binding(for: transaction),
								timeZone: timeZone
							)
						}
						.onDelete { offsets in
							delete(offsets, from: group.items)
						}
					} header: {
						Text(group.date, format: .dateTime.weekday(.wide).month().day())
							.font(.subheadline.weight(.semibold))
							.foregroundStyle(.secondary)
					}
				}
			}
			.listStyle(.plain)
		}
	}
	
	private var emptyState: some View {
		VStack(spacing: 12) {
			Spacer()
			if searchText.isEmpty {
				Image(systemName: "tray")
					.font(.system(size: 40))
					.foregroundStyle(.tertiary)
				Text("No transactions yet")
					.font(.headline)
					.foregroundStyle(.secondary)
				Text("Tap + to add your first transaction")
					.font(.subheadline)
					.foregroundStyle(.tertiary)
				
				Button("Add Transaction") {
					startsAsRecurring = false
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
	
	private func delete(_ offsets: IndexSet, from items: [Transaction]) {
		for index in offsets {
			let transaction = items[index]
			expandedTransactionIDs.remove(transaction.id)
			account.balance -= transaction.amount
			
			if let transferGroupID = transaction.transferGroupID {
				if let counterpart = allTransactions.first(where: {
					$0.transferGroupID == transferGroupID && $0.id != transaction.id
				}) {
					counterpart.account?.balance -= counterpart.amount
					modelContext.delete(counterpart)
				}
			}
			
			modelContext.delete(transaction)
		}
		
		do {
			try modelContext.save()
		} catch {
			saveErrorMessage = error.localizedDescription
		}
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
