import SwiftUI

struct TransactionRow: View {
	let transaction: Transaction
	@Binding var isExpanded: Bool
	let timeZone: TimeZone
	
	private var iconName: String {
		switch transaction.type {
		case .expense:
			return "arrow.up.right"
		case .income:
			return "arrow.down.left"
		case .transferOut:
			return "arrow.right.arrow.left.circle.fill"
		case .transferIn:
			return "arrow.left.arrow.right.circle.fill"
		}
	}
	
	private var typeName: String {
		switch transaction.type {
		case .expense:
			return "Expense"
		case .income:
			return "Income"
		case .transferOut:
			return "Transfer Out"
		case .transferIn:
			return "Transfer In"
		}
	}
	
	private var accentColor: Color {
		switch transaction.type {
		case .expense:
			return .red
		case .income:
			return .green
		case .transferOut:
			return .blue
		case .transferIn:
			return .mint
		}
	}
	
	private var amountColor: Color {
		switch transaction.type {
		case .expense:
			return .primary
		case .income:
			return .green
		case .transferOut:
			return .blue
		case .transferIn:
			return .mint
		}
	}
	
	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			Button {
				withAnimation(.easeInOut(duration: 0.2)) {
					isExpanded.toggle()
				}
			} label: {
				HStack(spacing: 12) {
					Image(systemName: "chevron.right")
						.font(.caption.weight(.semibold))
						.foregroundStyle(.secondary)
						.rotationEffect(.degrees(isExpanded ? 90 : 0))
						.frame(width: 12, height: 12)
					
					Circle()
						.fill(accentColor.opacity(0.16))
						.frame(width: 36, height: 36)
						.overlay {
							Image(systemName: iconName)
								.font(.caption.weight(.bold))
								.foregroundStyle(accentColor)
						}
					
					VStack(alignment: .leading, spacing: 2) {
						Text(transaction.note.isEmpty ? "Transaction" : transaction.note)
							.font(.body)
							.lineLimit(isExpanded ? nil : 1)
						Text(transaction.date, format: .dateTime.hour().minute())
							.font(.caption)
							.foregroundStyle(.secondary)
					}
					
					Spacer()
					
					Text(transaction.amount, format: .currency(code: transaction.account?.currency ?? "USD"))
						.font(.body.weight(.semibold))
						.foregroundStyle(amountColor)
				}
				.padding(.vertical, 8)
				.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			
			if isExpanded {
				VStack(alignment: .leading, spacing: 12) {
					detailRow("Type", value: typeName)
					detailRow(
						"Date",
						value: formattedDetailDate(transaction.date)
					)
					detailRow("Account", value: transaction.account?.name ?? "Unassigned")
					if transaction.type == .transferOut || transaction.type == .transferIn {
						detailRow("Counterparty", value: transaction.relatedAccount?.name ?? "Unknown")
					}
					detailRow("Reference", value: transaction.id.uuidString)
				}
				.padding(.top, 8)
				.padding(.leading, 24)
			}
		}
		.animation(.default, value: isExpanded)
	}
	
	@ViewBuilder
	private func detailRow(_ label: String, value: String) -> some View {
		HStack(alignment: .firstTextBaseline, spacing: 12) {
			Text(label)
				.font(.caption.weight(.medium))
				.foregroundStyle(.secondary)
				.frame(width: 72, alignment: .leading)
			
			Text(value)
				.font(.caption)
				.textSelection(.enabled)
			
			Spacer(minLength: 0)
		}
	}
	
	private func formattedDetailDate(_ date: Date) -> String {
		let formatter = DateFormatter()
		formatter.timeZone = timeZone
		formatter.dateStyle = .full
		formatter.timeStyle = .short
		return formatter.string(from: date)
	}
}

#Preview {
	@Previewable @State var isExpanded = true
	
	List {
		TransactionRow(
			transaction: Transaction(
				amount: -42.50,
				note: "Coffee with team",
				date: .now,
				account: Account(name: "Chase Checking", icon: "🏦", category: .checking, balance: 1250.42)
			),
			isExpanded: $isExpanded,
			timeZone: .autoupdatingCurrent
		)
	}
	.listStyle(.plain)
	}
