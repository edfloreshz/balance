import SwiftUI

struct TransactionRow: View {
	let transaction: Transaction
	@Binding var isExpanded: Bool
	
	private var isPositive: Bool {
		transaction.amount >= 0
	}
	
	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			Button {
				isExpanded.toggle()
			} label: {
				HStack(spacing: 12) {
					Image(systemName: "chevron.right")
						.font(.caption.weight(.semibold))
						.foregroundStyle(.secondary)
						.rotationEffect(.degrees(isExpanded ? 90 : 0))
						.frame(width: 12, height: 12)
					
					Circle()
						.fill((isPositive ? Color.green : Color.red).opacity(0.15))
						.frame(width: 36, height: 36)
						.overlay {
							Image(systemName: isPositive ? "arrow.down.left" : "arrow.up.right")
								.font(.caption.weight(.bold))
								.foregroundStyle(isPositive ? .green : .red)
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
						.foregroundStyle(isPositive ? .green : .primary)
				}
				.padding(.vertical, 8)
				.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			
			if isExpanded {
				VStack(alignment: .leading, spacing: 12) {
					detailRow("Type", value: isPositive ? "Income" : "Expense")
					detailRow(
						"Date",
						value: transaction.date.formatted(
							.dateTime.weekday(.wide).month().day().year().hour().minute()
						)
					)
					detailRow("Account", value: transaction.account?.name ?? "Unassigned")
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
			isExpanded: $isExpanded
		)
	}
	.listStyle(.plain)
	}
