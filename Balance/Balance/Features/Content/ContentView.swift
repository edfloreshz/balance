//
//  ContentView.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
	@Bindable var viewModel: MasterViewModel
	@Environment(\.modelContext) private var modelContext
	@Query var accounts: [Account]
	@State private var editingAccount: Account?
	@State private var saveErrorMessage: String?
	
	init(viewModel: MasterViewModel) {
		self.viewModel = viewModel
		
		let targetCategoryRawValue = viewModel.selectedCategory.rawValue
		
		let predicate = #Predicate<Account> { account in
			account.categoryRawValue == targetCategoryRawValue
		}
		
		_accounts = Query(filter: predicate, sort: \.name)
	}

	private var filteredAccounts: [Account] {
		guard !viewModel.accountSearchText.isEmpty else { return accounts }
		return accounts.filter { account in
			account.name.localizedCaseInsensitiveContains(viewModel.accountSearchText)
			|| account.currency.localizedCaseInsensitiveContains(viewModel.accountSearchText)
		}
	}
	
    var body: some View {
		Group {
			if accounts.isEmpty {
				VStack(spacing: 16) {
					ContentUnavailableView(
						"Accounts",
						systemImage: "dollarsign.circle",
						description: Text("Accounts will appear here")
					)
#if os(macOS)
					Button("Add Account") {
						viewModel.showingAddAccount = true
					}
					.buttonStyle(.glassProminent)
#endif
				}
			} else {
				VStack(spacing: 0) {
					if filteredAccounts.isEmpty {
						VStack {
							Spacer()
							ContentUnavailableView.search(text: viewModel.accountSearchText)
							Spacer()
						}
						.frame(maxWidth: .infinity, maxHeight: .infinity)
					} else {
						List(selection: $viewModel.selectedAccount) {
							ForEach(filteredAccounts) { account in
								NavigationLink(value: account) {
									AccountView(account: account)
								}
								.swipeActions(edge: .trailing, allowsFullSwipe: false) {
									Button {
										editingAccount = account
									} label: {
										Label("Edit", systemImage: "pencil")
									}
									.tint(.blue)
									
									Button(role: .destructive) {
										delete(account)
									} label: {
										Label("Delete", systemImage: "trash")
									}
								}
								.swipeActions(edge: .leading, allowsFullSwipe: true) {
									Button {
										viewModel.selectedAccount = account
										viewModel.showAddTransaction(initialKind: .transferOut)
									} label: {
										Label("Transfer", systemImage: "arrow.left.arrow.right")
									}
									.help("Transfer from this account")
								}
								.tag(account)
							}
						}
					}
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
			}
		}
		.navigationTitle("Accounts")
#if !os(macOS)
		.navigationBarTitleDisplayMode(.inline)
#endif
		.onChange(of: viewModel.accountSearchText) { _, _ in
			guard let selectedAccount = viewModel.selectedAccount else { return }
			if !filteredAccounts.contains(where: { $0.id == selectedAccount.id }) {
				viewModel.selectedAccount = nil
			}
		}
		.sheet(item: $editingAccount) { account in
			AccountEditorView(account: account)
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
    }

	private func delete(_ account: Account) {
		if viewModel.selectedAccount?.id == account.id {
			viewModel.selectedAccount = nil
		}
		
		modelContext.delete(account)
		
		do {
			try modelContext.save()
		} catch {
			saveErrorMessage = error.localizedDescription
		}
	}

}

#Preview {
	ContentView(viewModel: MasterViewModel())
		.modelContainer(PreviewData.shared.modelContainer)
}
