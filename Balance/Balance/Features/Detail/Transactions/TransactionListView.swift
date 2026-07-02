//
//  TransactionsContentView.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import SwiftData
import SwiftUI

struct TransactionListView: View {
	enum Mode {
		case transactions
		case recurring
	}

	@Bindable var account: Account
	@Bindable var viewModel: TransactionsViewModel
	private let mode: Mode
	
	@Environment(\.modelContext) private var modelContext
	@Environment(\.timeZone) private var timeZone
	@Query private var transactions: [Transaction]
	@Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
	
	init(
		account: Account,
		mode: Mode = .transactions,
		viewModel: TransactionsViewModel
	) {
		self.account = account
		self.mode = mode
		self.viewModel = viewModel
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
		if viewModel.searchText.isEmpty {
			source = transactions
		} else {
			source = transactions.filter { transaction in
				switch mode {
				case .transactions:
					return transaction.note.localizedCaseInsensitiveContains(viewModel.searchText)
				case .recurring:
					let searchable = [
						transaction.note,
						transaction.type.displayName,
						transaction.frequency.displayName,
						transaction.account?.name ?? "",
						transaction.relatedAccount?.name ?? ""
					].joined(separator: " ")
					return searchable.localizedCaseInsensitiveContains(viewModel.searchText)
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
		transactions.filter { viewModel.selectedTransactionIDs.contains($0.id) }
	}

	private var canEditSelectedTransaction: Bool {
		viewModel.canEditSelectedTransaction
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
					List(selection: $viewModel.selectedTransactionIDs) {
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
					List(selection: $viewModel.selectedTransactionIDs) {
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
		.sheet(item: $viewModel.editingTransaction) { transaction in
			TransactionEditorView(transaction: transaction)
		}
		.onChange(of: filteredTransactions.map(\.id)) { _, visibleIDs in
			viewModel.retainSelectedTransactionIDs(visibleIDs: visibleIDs)
		}
#if os(macOS)
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
					viewModel.showingDeleteTransactionsConfirmation = !viewModel.selectedTransactionIDs.isEmpty
				} label: {
					Label("Delete", systemImage: "trash")
				}
				.help("Delete")
				.disabled(viewModel.selectedTransactionIDs.isEmpty)
			}
		}
#endif
		.confirmationDialog(
			"Delete Transactions?",
			isPresented: $viewModel.showingDeleteTransactionsConfirmation,
			titleVisibility: .visible
		) {
			Button("Delete Transactions", role: .destructive) {
				deleteSelectedTransactions()
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			let transactionCount = viewModel.selectedTransactionIDs.count
			Text(transactionCount == 1
				? "This transaction will be permanently deleted."
				: "\(transactionCount) transactions will be permanently deleted.")
		}
	}
	
	private var emptyState: some View {
		VStack(spacing: 12) {
			Spacer()
			if viewModel.searchText.isEmpty {
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
#if os(macOS)
					Button("Add Transaction") {
						viewModel.startsAsRecurring = false
						viewModel.showingAddTransaction = true
					}
					.buttonStyle(.glassProminent)
#endif
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
#if os(macOS)
					Button("Add Recurrent Transaction") {
						viewModel.startsAsRecurring = true
						viewModel.showingAddTransaction = true
					}
					.buttonStyle(.glassProminent)
#endif	
				}
			} else {
				ContentUnavailableView.search(text: viewModel.searchText)
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
			viewModel.saveErrorMessage = error.localizedDescription
		}
	}

	private func delete(_ transaction: Transaction) {
		delete(transaction, saveAfterDelete: true)
	}

	private func delete(_ transaction: Transaction, saveAfterDelete: Bool) {
		viewModel.expandedTransactionIDs.remove(transaction.id)
		viewModel.selectedTransactionIDs.remove(transaction.id)

		if mode == .transactions {
			account.balance -= transaction.amount
			
			if let transferGroupID = transaction.transferGroupID {
				if let counterpart = allTransactions.first(where: {
					$0.transferGroupID == transferGroupID && $0.id != transaction.id
				}) {
					viewModel.selectedTransactionIDs.remove(counterpart.id)
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
				viewModel.saveErrorMessage = error.localizedDescription
			}
		}
	}
	
	private func binding(for transaction: Transaction) -> Binding<Bool> {
		Binding(
			get: { viewModel.expandedTransactionIDs.contains(transaction.id) },
			set: { isExpanded in
				if isExpanded {
					viewModel.expandedTransactionIDs.insert(transaction.id)
				} else {
					viewModel.expandedTransactionIDs.remove(transaction.id)
				}
			}
		)
	}

	@ViewBuilder
	private func transactionRow(_ transaction: Transaction) -> some View {
		TransactionView(
			transaction: transaction,
			isExpanded: binding(for: transaction),
			timeZone: timeZone
		)
		.tag(transaction.id)
		.swipeActions(edge: .trailing, allowsFullSwipe: false) {
			Button {
				viewModel.editingTransaction = transaction
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
		viewModel.editingTransaction = selectedTransactions.first
	}

	private func deleteSelectedTransactions() {
		var pendingIDs = viewModel.selectedTransactionIDs
		
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
			viewModel.saveErrorMessage = error.localizedDescription
		}
	}
}

#Preview {
	TransactionListView(account: .sampleData[0], viewModel: .init())
}
