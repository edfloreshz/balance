//
//  DetailView.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import SwiftUI

struct DetailView: View {
	@Bindable var viewModel: MasterViewModel
	
    var body: some View {
		if let selectedAccount = viewModel.selectedAccount {
			TransactionsView(
				account: selectedAccount,
				viewModel: viewModel
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
	DetailView(viewModel: MasterViewModel())
}
