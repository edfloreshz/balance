import SwiftUI

struct AccountSummaryHeader: View {
	let account: Account
	
	var body: some View {
		VStack(spacing: 4) {
			HStack(spacing: 6) {
				Text(account.category.icon)
				Text(account.category.name)
					.font(.caption.weight(.medium))
					.foregroundStyle(.secondary)
			}
			
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
	AccountSummaryHeader(
		account: Account(name: "Chase Checking", icon: "🏦", category: .checking, balance: 1250.42)
	)
}
