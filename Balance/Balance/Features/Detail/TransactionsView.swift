//
//  TransactionsView.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import SwiftData
import SwiftUI

struct TransactionsView: View {
	enum DetailTab: String, CaseIterable, Identifiable {
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
	
	@Bindable var account: Account
	@AppStorage(AppPreferences.usesAutomaticTimeZoneKey) private var usesAutomaticTimeZone: Bool = true
	@AppStorage(AppPreferences.selectedTimeZoneIdentifierKey) private var selectedTimeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier
	@State private var searchText: String = ""
	@State private var addTransactionMode: AddTransactionMode?
	@State private var saveErrorMessage: String?
	@State private var selectedTab: DetailTab = .transactions
	
	private var timeZone: TimeZone {
		AppPreferences.effectiveTimeZone(
			usesAutomaticTimeZone: usesAutomaticTimeZone,
			selectedTimeZoneIdentifier: selectedTimeZoneIdentifier
		)
	}
	
	private var showingAddTransactionBinding: Binding<Bool> {
		Binding(
			get: { addTransactionMode != nil },
			set: { shouldShow in
				if !shouldShow {
					addTransactionMode = nil
				} else if addTransactionMode == nil {
					addTransactionMode = .oneTime
				}
			}
		)
	}
	
	private var startsAsRecurringBinding: Binding<Bool> {
		Binding(
			get: { addTransactionMode == .recurring },
			set: { startsAsRecurring in
				addTransactionMode = startsAsRecurring ? .recurring : .oneTime
			}
		)
	}
	
	var body: some View {
		VStack(spacing: 0) {
			AccountSummaryHeader(account: account)
			tabPicker
			
			if selectedTab == .transactions {
				TransactionsListView(
					account: account,
					searchText: $searchText,
					showingAddTransaction: showingAddTransactionBinding,
					startsAsRecurring: startsAsRecurringBinding,
					saveErrorMessage: $saveErrorMessage
				)
			} else {
				RecurringTransactionsView(
					account: account,
					searchText: searchText,
					showingAddTransaction: showingAddTransactionBinding,
					startsAsRecurring: startsAsRecurringBinding,
					saveErrorMessage: $saveErrorMessage
				)
			}
		}
		.searchable(text: $searchText, prompt: "Search transactions")
		.navigationTitle(account.name)
		.toolbar(content: toolbarContent)
#if os(iOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
			.sheet(item: $addTransactionMode) { mode in
				AddTransactionView(account: account, startsAsRecurring: mode == .recurring)
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
	
	private var tabPicker: some View {
		Picker("", selection: $selectedTab) {
			ForEach(DetailTab.allCases) { tab in
				Text(tab.title).tag(tab)
			}
		}
		.pickerStyle(.segmented)
		.padding(.horizontal, 16)
		.padding(.vertical, 12)
	}
}

#Preview {
	NavigationStack {
		TransactionsView(account: Account(name: "Chase Checking", category: .checking, balance: 1250.42))
	}
	.modelContainer(for: [Account.self, Transaction.self], inMemory: true)
}
