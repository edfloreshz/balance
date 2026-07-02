//
//  AccountView.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//
import SwiftUI

struct AccountRow: View {
	let account: Account
	let onTransferFrom: (() -> Void)?
	
	init(account: Account, onTransferFrom: (() -> Void)? = nil) {
		self.account = account
		self.onTransferFrom = onTransferFrom
	}
	
	var body: some View {
		HStack(spacing: 12) {
			ZStack {
				Circle()
					.fill(account.category.color.opacity(0.15))
					.frame(width: 40, height: 40)
				
				Text(account.icon.isEmpty ? account.category.icon : account.icon)
					.font(.system(size: 18))
			}
			
			VStack(alignment: .leading, spacing: 2) {
				Text(account.name)
					.font(.body.weight(.medium))
					.lineLimit(1)
				
				Text(account.category.name)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			
			Spacer()
			
			Text(account.balance, format: .currency(code: account.currency))
				.font(.body.weight(.semibold))
				.foregroundStyle(account.balance >= 0 ? Color.primary : Color.red)
				.monospacedDigit()
			
			if let onTransferFrom {
				Menu {
					Button {
						onTransferFrom()
					} label: {
						Label("Transfer from this account", systemImage: "arrow.left.arrow.right")
					}
				} label: {
					Image(systemName: "ellipsis.circle")
						.font(.title3)
						.foregroundStyle(.secondary)
				}
				.buttonStyle(.borderless)
			}
		}
		.padding(.vertical, 6)
		.opacity(account.isArchived ? 0.5 : 1)
	}
}

#Preview {
	List {
		AccountRow(account: .init(name: "BBVA", icon: "🏦", category: .savings, balance: 15230.75))
		AccountRow(account: .init(name: "BBVA Oro", icon: "🏦", category: .creditCard, balance: -2340.10))
		AccountRow(account: .init(name: "Crypto", icon: "🏦", category: .investment, balance: 8900))
	}
	.listStyle(.plain)
}
