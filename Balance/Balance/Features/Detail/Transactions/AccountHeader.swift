//
//  AccountHeader.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import SwiftUI

struct AccountHeader: View {
	let account: Account
	
	var body: some View {
		VStack(spacing: 6) {
			HStack(spacing: 6) {
				Text(account.category.icon)
				Text(account.category.name)
					.font(.caption.weight(.medium))
					.foregroundStyle(.secondary)
			}
			
			Text(account.name)
				.font(.title3.weight(.semibold))
			
			Text(account.balance, format: .currency(code: account.currency))
				.font(.system(size: 34, weight: .bold, design: .rounded))
				.foregroundStyle(account.balance >= 0 ? Color.primary : Color.red)
				.contentTransition(.numericText())
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 40)
		.background(account.category.color.opacity(0.08))
	}
}

#Preview {
	AccountHeader(
		account: Account(name: "Chase Checking", icon: "🏦", category: .checking, balance: 1250.42)
	)
}
