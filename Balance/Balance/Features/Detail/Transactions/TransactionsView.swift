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
	@Bindable var viewModel: MasterViewModel
	@AppStorage(AppPreferences.usesAutomaticTimeZoneKey) private var usesAutomaticTimeZone: Bool = true
	@AppStorage(AppPreferences.selectedTimeZoneIdentifierKey) private var selectedTimeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier
	@State private var transactionsViewModel = TransactionsViewModel()
	
	private var timeZone: TimeZone {
		AppPreferences.effectiveTimeZone(
			usesAutomaticTimeZone: usesAutomaticTimeZone,
			selectedTimeZoneIdentifier: selectedTimeZoneIdentifier
		)
	}
	
	var body: some View {
		@Bindable var transactionsViewModel = transactionsViewModel

		VStack(spacing: 0) {
			AccountHeader(account: account)
			tabPicker
			
			TransactionListView(
				account: account,
				mode: transactionsViewModel.mode,
				viewModel: transactionsViewModel
			)
		}
		.navigationTitle(account.name)
#if os(iOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
			.sheet(item: $transactionsViewModel.addTransactionMode) { mode in
				TransactionEditorView(account: account, startsAsRecurring: mode == .recurring)
			}
			.sheet(isPresented: $viewModel.showingEditAccount) {
				AccountEditorView(account: account)
			}
			.alert(
				"Couldn't Update Account",
				isPresented: Binding(
					get: { transactionsViewModel.saveErrorMessage != nil },
					set: { if !$0 { transactionsViewModel.saveErrorMessage = nil } }
				)
			) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(transactionsViewModel.saveErrorMessage ?? "Something went wrong.")
			}
		.environment(\.timeZone, timeZone)
		.onAppear {
			AppPreferences.synchronizeAutomaticTimeZoneIfNeeded()
			transactionsViewModel.searchText = viewModel.transactionSearchText
		}
		.onChange(of: transactionsViewModel.searchText) { _, newValue in
			if viewModel.transactionSearchText != newValue {
				viewModel.transactionSearchText = newValue
			}
		}
		.onChange(of: viewModel.transactionSearchText) { _, newValue in
			if transactionsViewModel.searchText != newValue {
				transactionsViewModel.searchText = newValue
			}
		}
	}
	
	private var tabPicker: some View {
		Picker("", selection: $transactionsViewModel.selectedTab) {
			ForEach(TransactionsDetailTab.allCases) { tab in
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
		TransactionsView(
			account: .init(name: "Chase Checking", category: .checking, balance: 1250.42),
			viewModel: MasterViewModel()
		)
	}
	.modelContainer(for: [Account.self, Transaction.self], inMemory: true)
}
