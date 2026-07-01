//
//  DetailView.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import SwiftUI

struct DetailView: View {
	@Binding var selectedAccount: Account?

    var body: some View {
		if let selectedAccount {
			TransactionsView(account: selectedAccount)
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
	
	DetailView(selectedAccount: $selectedAccount)
}
