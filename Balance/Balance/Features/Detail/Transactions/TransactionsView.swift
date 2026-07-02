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
	@Binding var searchText: String
	@State private var addTransactionMode: AddTransactionMode?
	@Binding var showingEditAccount: Bool
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
			
			TransactionsListView(
				account: account,
				mode: selectedTab == .transactions ? .transactions : .recurring,
				searchText: $searchText,
				showingAddTransaction: showingAddTransactionBinding,
				startsAsRecurring: startsAsRecurringBinding,
				saveErrorMessage: $saveErrorMessage
			)
		}
		.navigationTitle(account.name)
#if os(iOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
			.sheet(item: $addTransactionMode) { mode in
				AddTransactionView(account: account, startsAsRecurring: mode == .recurring)
			}
			.sheet(isPresented: $showingEditAccount) {
				AddAccountView(account: account)
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
	@Previewable @State var showingEditAccount: Bool = false
	
	NavigationStack {
		TransactionsView(
			account: .init(name: "Chase Checking", category: .checking, balance: 1250.42),
			searchText: .constant(""),
			showingEditAccount: $showingEditAccount
		)
	}
	.modelContainer(for: [Account.self, Transaction.self], inMemory: true)
}
