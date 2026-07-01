import SwiftData
import SwiftUI

struct AddTransactionView: View {
	let account: Account
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss
	
	@State private var note: String = ""
	@State private var amountText: String = ""
	@State private var date: Date = .now
	@State private var isExpense: Bool = true
	@State private var saveErrorMessage: String?
	
	private var amountValue: Double? {
		Double(amountText)
	}
	
	private var canSave: Bool {
		amountValue != nil
	}
	
	var body: some View {
		EditorSheet(
			title: "New Transaction",
			subtitle: "Add income or an expense to \(account.name)."
		) {
			EditorSection("Account") {
				HStack(spacing: 14) {
					ZStack {
						Circle()
							.fill(account.category.color.opacity(0.16))
							.frame(width: 44, height: 44)
						
						Text(account.icon.isEmpty ? account.category.icon : account.icon)
							.font(.title3)
					}
					
					VStack(alignment: .leading, spacing: 3) {
						Text(account.name)
							.font(.headline)
						Text(account.category.name)
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
					
					Spacer()
					
					Text(account.balance, format: .currency(code: account.currency))
						.font(.headline.weight(.semibold))
						.monospacedDigit()
				}
			}
			
			EditorSection("Transaction Details") {
				EditorFieldRow("Type") {
					Picker("Type", selection: $isExpense) {
						Text("Expense").tag(true)
						Text("Income").tag(false)
					}
					.pickerStyle(.segmented)
				}
				
				EditorFieldRow("Amount") {
					HStack(spacing: 10) {
						TextField("0.00", text: $amountText)
#if os(iOS)
							.keyboardType(.decimalPad)
#endif
							.textFieldStyle(.roundedBorder)
						
						Text(account.currency)
							.font(.subheadline.weight(.medium))
							.foregroundStyle(.secondary)
					}
				}
				
				EditorFieldRow("Note") {
					TextField("Description", text: $note)
						.textFieldStyle(.roundedBorder)
				}
				
				EditorFieldRow("Date") {
					DatePicker(
						"Date",
						selection: $date,
						displayedComponents: [.date, .hourAndMinute]
					)
					.labelsHidden()
				}
			}
			
			if let amountValue {
				EditorSection("Preview") {
					HStack {
						Text(isExpense ? "This will subtract" : "This will add")
							.foregroundStyle(.secondary)
						Spacer()
						Text(
							isExpense ? -abs(amountValue) : abs(amountValue),
							format: .currency(code: account.currency)
						)
						.font(.headline.weight(.semibold))
						.foregroundStyle(isExpense ? .red : .green)
						.monospacedDigit()
					}
				}
			}
		} actions: {
			Button("Cancel") {
				dismiss()
			}
			
			Button("Save") {
				save()
			}
			.keyboardShortcut(.defaultAction)
			.disabled(!canSave)
		}
		.alert(
			"Couldn't Save Transaction",
			isPresented: Binding(
				get: { saveErrorMessage != nil },
				set: { if !$0 { saveErrorMessage = nil } }
			)
		) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(saveErrorMessage ?? "Something went wrong.")
		}
	}
	
	private func save() {
		guard let rawAmount = amountValue else {
			saveErrorMessage = "Enter a valid amount."
			return
		}
		let amount = isExpense ? -abs(rawAmount) : abs(rawAmount)
		
		let transaction = Transaction(amount: amount, note: note, date: date, account: account)
		modelContext.insert(transaction)
		account.balance += amount
		
		do {
			try modelContext.save()
			dismiss()
		} catch {
			saveErrorMessage = error.localizedDescription
		}
	}
}

#Preview {
	AddTransactionView(
		account: Account(name: "Chase Checking", icon: "🏦", category: .checking, balance: 1250.42)
	)
	.modelContainer(PreviewData.shared.modelContainer)
}
