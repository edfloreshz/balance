//
//  ContentView.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
	@Binding var selectedCategory: Category
	@Binding var selectedAccount: Account?
	@Binding var searchText: String
	@Environment(\.modelContext) private var modelContext
	let onAddAccount: (() -> Void)?
	@Query var accounts: [Account]
	@State private var editingAccount: Account?
	@State private var saveErrorMessage: String?
	
	init(
		selectedCategory: Binding<Category>,
		selectedAccount: Binding<Account?>,
		searchText: Binding<String>,
		onAddAccount: (() -> Void)? = nil
	) {
		self._selectedCategory = selectedCategory
		self._selectedAccount = selectedAccount
		self._searchText = searchText
		self.onAddAccount = onAddAccount
		
		let targetCategoryRawValue = selectedCategory.wrappedValue.rawValue
		
		let predicate = #Predicate<Account> { account in
			account.categoryRawValue == targetCategoryRawValue
		}
		
		_accounts = Query(filter: predicate, sort: \.name)
	}

	private var filteredAccounts: [Account] {
		guard !searchText.isEmpty else { return accounts }
		return accounts.filter { account in
			account.name.localizedCaseInsensitiveContains(searchText)
			|| account.currency.localizedCaseInsensitiveContains(searchText)
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
					
					if let onAddAccount {
						Button("Add Account", action: onAddAccount)
							.buttonStyle(.borderedProminent)
					}
				}
			} else {
				VStack(spacing: 0) {
					if filteredAccounts.isEmpty {
						VStack {
							Spacer()
							ContentUnavailableView.search(text: searchText)
							Spacer()
						}
						.frame(maxWidth: .infinity, maxHeight: .infinity)
					} else {
						List(selection: $selectedAccount) {
							ForEach(filteredAccounts) { account in
								NavigationLink(value: account) {
									AccountRow(account: account)
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
								.tag(account)
							}
						}
					}
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
			}
		}
		.onChange(of: searchText) { _, _ in
			guard let selectedAccount else { return }
			if !filteredAccounts.contains(where: { $0.id == selectedAccount.id }) {
				self.selectedAccount = nil
			}
		}
		.sheet(item: $editingAccount) { account in
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
    }

	private func delete(_ account: Account) {
		if selectedAccount?.id == account.id {
			selectedAccount = nil
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
	@Previewable @State var selectedCategory: Category = .savings
	@Previewable @State var selectedAccount: Account? = nil
	@Previewable @State var searchText: String = ""

	ContentView(selectedCategory: $selectedCategory, selectedAccount: $selectedAccount, searchText: $searchText)
		.modelContainer(PreviewData.shared.modelContainer)
}
