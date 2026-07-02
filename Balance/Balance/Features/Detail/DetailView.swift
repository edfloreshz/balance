//
//  DetailView.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import SwiftUI

struct DetailView: View {
	@Binding var selectedAccount: Account?
	@Binding var showingEditAccount: Bool
	@Binding var searchText: String
	
    var body: some View {
		if let selectedAccount {
			TransactionsView(
				account: selectedAccount,
				searchText: $searchText,
				showingEditAccount: $showingEditAccount
			)
		} else {
			ContentUnavailableView(
				"Details",
				systemImage: "list.bullet.clipboard",
				description: Text("Account details will appear here")
			)
		}
    }
}

#Preview {
	@Previewable @State var selectedAccount: Account? = nil
	@Previewable @State var showingEditAccount: Bool = false
	@Previewable @State var searchText: String = ""

	DetailView(
		selectedAccount: $selectedAccount,
		showingEditAccount: $showingEditAccount,
		searchText: $searchText
	)
}
