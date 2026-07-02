//
//  TransactionsContentView.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import SwiftData
import SwiftUI

struct TransactionsListView: View {
	enum Mode {
		case transactions
		case recurring
	}

	@Bindable var account: Account
	private let mode: Mode
	@Binding var searchText: String
	@Binding var showingAddTransaction: Bool
	@Binding var startsAsRecurring: Bool
	@Binding var saveErrorMessage: String?
	
	@Environment(\.modelContext) private var modelContext
	@Environment(\.timeZone) private var timeZone
	@Query private var transactions: [Transaction]
	@Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
	@State private var expandedTransactionIDs: Set<UUID> = []
	@State private var selectedTransactionIDs: Set<UUID> = []
	@State private var showingDeleteTransactionsConfirmation = false
	@State private var editingTransaction: Transaction?
	
	init(
		account: Account,
		mode: Mode = .transactions,
		searchText: Binding<String>,
		showingAddTransaction: Binding<Bool>,
		startsAsRecurring: Binding<Bool>,
		saveErrorMessage: Binding<String?>
	) {
		self.account = account
		self.mode = mode
		self._searchText = searchText
		self._showingAddTransaction = showingAddTransaction
		self._startsAsRecurring = startsAsRecurring
		self._saveErrorMessage = saveErrorMessage
		let accountID = account.id

		let predicate: Predicate<Transaction>
		switch mode {
		case .transactions:
			predicate = #Predicate<Transaction> { transaction in
				transaction.account?.id == accountID
				&& (transaction.recurrenceFrequencyRawValue == nil || transaction.recurrenceSeriesID != nil)
			}
		case .recurring:
			predicate = #Predicate<Transaction> { transaction in
				transaction.account?.id == accountID
				&& transaction.recurrenceFrequencyRawValue != nil
				&& transaction.recurrenceSeriesID == nil
			}
		}

		_transactions = Query(filter: predicate, sort: \.date, order: .reverse)
	}
	
	private var filteredTransactions: [Transaction] {
		let source: [Transaction]
		if searchText.isEmpty {
			source = transactions
		} else {
			source = transactions.filter { transaction in
				switch mode {
				case .transactions:
					return transaction.note.localizedCaseInsensitiveContains(searchText)
				case .recurring:
					let searchable = [
						transaction.note,
						transaction.type.displayName,
						transaction.frequency.displayName,
						transaction.account?.name ?? "",
						transaction.relatedAccount?.name ?? ""
					].joined(separator: " ")
					return searchable.localizedCaseInsensitiveContains(searchText)
				}
			}
		}

		if mode == .recurring {
			return source.sorted { $0.nextOccurrenceDate < $1.nextOccurrenceDate }
		}

		return source
	}
	
	private var groupedTransactions: [(date: Date, items: [Transaction])] {
		let groups = Dictionary(grouping: filteredTransactions) { transaction in
			calendar.startOfDay(for: transaction.date)
		}
		return groups
			.map { (date: $0.key, items: $0.value) }
			.sorted { $0.date > $1.date }
	}

	private var selectedTransactions: [Transaction] {
		transactions.filter { selectedTransactionIDs.contains($0.id) }
	}

	private var canEditSelectedTransaction: Bool {
		selectedTransactions.count == 1
	}
	
	private var calendar: Calendar {
		var calendar = Calendar.autoupdatingCurrent
		calendar.timeZone = timeZone
		return calendar
	}
	
	var body: some View {
		Group {
			if filteredTransactions.isEmpty {
				emptyState
			} else {
				if mode == .transactions {
					List(selection: $selectedTransactionIDs) {
						ForEach(groupedTransactions, id: \.date) { group in
							Section {
								ForEach(group.items) { transaction in
									transactionRow(transaction)
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
				} else {
					List(selection: $selectedTransactionIDs) {
						ForEach(filteredTransactions) { transaction in
							transactionRow(transaction)
						}
						.onDelete { offsets in
							delete(offsets, from: filteredTransactions)
						}
					}
					.listStyle(.plain)
				}
			}
		}
		.sheet(item: $editingTransaction) { transaction in
			EditTransactionView(transaction: transaction)
		}
		.onChange(of: filteredTransactions.map(\.id)) { _, visibleIDs in
			let visibleIDSet = Set(visibleIDs)
			selectedTransactionIDs = selectedTransactionIDs.intersection(visibleIDSet)
		}
		.toolbar {
			ToolbarSpacer(.fixed)
			ToolbarItemGroup(placement: .confirmationAction) {
				Button {
					editSelectedTransaction()
				} label: {
					Label("Edit", systemImage: "pencil")
				}
				.help("Edit")
				.disabled(!canEditSelectedTransaction)
				
				Button(role: .destructive) {
					showingDeleteTransactionsConfirmation = !selectedTransactionIDs.isEmpty
				} label: {
					Label("Delete", systemImage: "trash")
				}
				.help("Delete")
				.disabled(selectedTransactionIDs.isEmpty)
			}
		}
		.confirmationDialog(
			"Delete Transactions?",
			isPresented: $showingDeleteTransactionsConfirmation,
			titleVisibility: .visible
		) {
			Button("Delete Transactions", role: .destructive) {
				deleteSelectedTransactions()
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			let transactionCount = selectedTransactionIDs.count
			Text(transactionCount == 1
				? "This transaction will be permanently deleted."
				: "\(transactionCount) transactions will be permanently deleted.")
		}
	}
	
	private var emptyState: some View {
		VStack(spacing: 12) {
			Spacer()
			if searchText.isEmpty {
				if mode == .transactions {
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
				}
			} else {
				ContentUnavailableView.search(text: searchText)
			}
			Spacer()
		}
		.frame(maxWidth: .infinity)
	}
	
	private func delete(_ offsets: IndexSet, from items: [Transaction]) {
		for index in offsets {
			delete(items[index], saveAfterDelete: false)
		}
		
		do {
			try modelContext.save()
		} catch {
			saveErrorMessage = error.localizedDescription
		}
	}

	private func delete(_ transaction: Transaction) {
		delete(transaction, saveAfterDelete: true)
	}

	private func delete(_ transaction: Transaction, saveAfterDelete: Bool) {
		expandedTransactionIDs.remove(transaction.id)
		selectedTransactionIDs.remove(transaction.id)

		if mode == .transactions {
			account.balance -= transaction.amount
			
			if let transferGroupID = transaction.transferGroupID {
				if let counterpart = allTransactions.first(where: {
					$0.transferGroupID == transferGroupID && $0.id != transaction.id
				}) {
					selectedTransactionIDs.remove(counterpart.id)
					counterpart.account?.balance -= counterpart.amount
					modelContext.delete(counterpart)
				}
			}
		}
		
		modelContext.delete(transaction)

		if saveAfterDelete {
			do {
				try modelContext.save()
			} catch {
				saveErrorMessage = error.localizedDescription
			}
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

	@ViewBuilder
	private func transactionRow(_ transaction: Transaction) -> some View {
		TransactionRow(
			transaction: transaction,
			isExpanded: binding(for: transaction),
			timeZone: timeZone
		)
		.tag(transaction.id)
		.swipeActions(edge: .trailing, allowsFullSwipe: false) {
			Button {
				editingTransaction = transaction
			} label: {
				Label("Edit", systemImage: "pencil")
			}
			.tint(.blue)
			
			Button(role: .destructive) {
				delete(transaction)
			} label: {
				Label("Delete", systemImage: "trash")
			}
		}
	}

	private func editSelectedTransaction() {
		guard canEditSelectedTransaction else { return }
		editingTransaction = selectedTransactions.first
	}

	private func deleteSelectedTransactions() {
		var pendingIDs = selectedTransactionIDs
		
		while let transactionID = pendingIDs.first {
			guard let transaction = allTransactions.first(where: { $0.id == transactionID }) else {
				pendingIDs.remove(transactionID)
				continue
			}
			
			pendingIDs.remove(transactionID)
			
			if mode == .transactions, let transferGroupID = transaction.transferGroupID {
				if let counterpart = allTransactions.first(where: {
					$0.transferGroupID == transferGroupID && $0.id != transaction.id
				}) {
					pendingIDs.remove(counterpart.id)
				}
			}
			
			delete(transaction, saveAfterDelete: false)
		}
		
		do {
			try modelContext.save()
		} catch {
			saveErrorMessage = error.localizedDescription
		}
	}
}
