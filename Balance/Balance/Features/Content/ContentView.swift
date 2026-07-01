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
	
    var body: some View {
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
			List(selection: $selectedAccount) {
				ForEach(accounts) { account in
					NavigationLink(value: account) {
						AccountRow(account: account)
					}
					.tag(account)
				}
			}
		}
    }
}

#Preview {
	@Previewable @State var selectedCategory: Category = .savings
	@Previewable @State var selectedAccount: Account? = nil

	ContentView(selectedCategory: $selectedCategory, selectedAccount: $selectedAccount)
		.modelContainer(PreviewData.shared.modelContainer)
}
