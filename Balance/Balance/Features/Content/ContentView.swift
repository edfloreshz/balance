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
	let onAddAccount: (() -> Void)?
	@Query var accounts: [Account]
	@State private var searchText = ""
	
	init(
		selectedCategory: Binding<Category>,
		selectedAccount: Binding<Account?>,
		onAddAccount: (() -> Void)? = nil
	) {
		self._selectedCategory = selectedCategory
		self._selectedAccount = selectedAccount
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
					searchField

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
    }

	private var searchField: some View {
		HStack(spacing: 10) {
			Image(systemName: "magnifyingglass")
				.foregroundStyle(.secondary)

			TextField("Search accounts", text: $searchText)
				.textFieldStyle(.plain)

			if !searchText.isEmpty {
				Button {
					searchText = ""
				} label: {
					Image(systemName: "xmark.circle.fill")
						.foregroundStyle(.tertiary)
				}
				.buttonStyle(.plain)
			}
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 10)
		.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
		.overlay {
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.strokeBorder(.quaternary, lineWidth: 1)
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 12)
	}
}

#Preview {
	@Previewable @State var selectedCategory: Category = .savings
	@Previewable @State var selectedAccount: Account? = nil

	ContentView(selectedCategory: $selectedCategory, selectedAccount: $selectedAccount)
		.modelContainer(PreviewData.shared.modelContainer)
}
