//
//  TransactionsView.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import SwiftData
import SwiftUI

struct TransactionsView: View {
	@Bindable var account: Account
	@Environment(\.modelContext) private var modelContext
	
	@Query private var transactions: [Transaction]
	@Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
	@AppStorage(AppPreferences.usesAutomaticTimeZoneKey) private var usesAutomaticTimeZone: Bool = true
	@AppStorage(AppPreferences.selectedTimeZoneIdentifierKey) private var selectedTimeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier
	@State private var searchText: String = ""
	@State private var showingAddTransaction = false
	@State private var saveErrorMessage: String?
	@State private var expandedTransactionIDs: Set<UUID> = []
	
	init(account: Account) {
		self.account = account
		let accountID = account.id
		
		let predicate = #Predicate<Transaction> { transaction in
			transaction.account?.id == accountID
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
	
	private var timeZone: TimeZone {
		AppPreferences.effectiveTimeZone(
			usesAutomaticTimeZone: usesAutomaticTimeZone,
			selectedTimeZoneIdentifier: selectedTimeZoneIdentifier
		)
	}
	
	private var calendar: Calendar {
		var calendar = Calendar.autoupdatingCurrent
		calendar.timeZone = timeZone
		return calendar
	}
	
	var body: some View {
		VStack(spacing: 0) {
			AccountSummaryHeader(account: account)
			
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
		.searchable(text: $searchText, prompt: "Search transactions")
		.navigationTitle(account.name)
		.toolbar(content: toolbarContent)
#if os(iOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
			.sheet(isPresented: $showingAddTransaction) {
				AddTransactionView(account: account)
			}
			.alert(
				"Couldn't Update Account",
				isPresented: Binding(
					get: { saveErrorMessage != nil },
					set: { if !$0 { saveErrorMessage = nil } }
				)
			) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(saveErrorMessage ?? "Something went wrong.")
			}
		.environment(\.timeZone, timeZone)
		.onAppear {
			AppPreferences.synchronizeAutomaticTimeZoneIfNeeded()
		}
	}

	@ToolbarContentBuilder
	private func toolbarContent() -> some ToolbarContent {
		DefaultToolbarItem(kind: .search, placement: .navigation)
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

#Preview {
	NavigationStack {
		TransactionsView(account: Account(name: "Chase Checking", category: .checking, balance: 1250.42))
	}
	.modelContainer(for: [Account.self, Transaction.self], inMemory: true)
}
