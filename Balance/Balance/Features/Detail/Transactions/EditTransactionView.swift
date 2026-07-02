import SwiftData
import SwiftUI

struct EditTransactionView: View {
	@Bindable var transaction: Transaction
	@Environment(\.dismiss) private var dismiss
	@Environment(\.modelContext) private var modelContext
	@Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

	@State private var note: String = ""
	@State private var amountText: String = ""
	@State private var date: Date = .now
	@State private var recurrenceFrequency: RecurrenceFrequency = .monthly
	@State private var hasRecurrenceEndDate: Bool = false
	@State private var recurrenceEndDate: Date = .now
	@State private var saveErrorMessage: String?

	private var currencyCode: String {
		transaction.account?.currency ?? "USD"
	}

	private var amountValue: Double? {
		Double(amountText)
	}

	private var isRecurringTemplate: Bool {
		transaction.isRecurringTemplate
	}

	private var recurrenceStartDate: Date {
		date
	}

	private var recurrenceRangeIsValid: Bool {
		!isRecurringTemplate || !hasRecurrenceEndDate || recurrenceEndDate >= recurrenceStartDate
	}

	private var canSave: Bool {
		amountValue != nil && recurrenceRangeIsValid
	}

	var body: some View {
		EditorSheet(
			title: "Edit Transaction",
			subtitle: "Update amount, note, and schedule details."
		) {
			EditorSection("Details") {
				EditorFieldRow("Type") {
					Text(transaction.type.displayName)
						.frame(maxWidth: .infinity, alignment: .leading)
				}

				EditorFieldRow("Amount") {
					HStack(spacing: 10) {
						TextField("0.00", text: $amountText)
#if os(iOS)
							.keyboardType(.decimalPad)
#endif
							.textFieldStyle(.roundedBorder)
						Text(currencyCode)
							.font(.subheadline.weight(.medium))
							.foregroundStyle(.secondary)
					}
				}

				EditorFieldRow("Note") {
					TextField("Description", text: $note)
						.textFieldStyle(.roundedBorder)
				}

				EditorFieldRow(isRecurringTemplate ? "Start Date" : "Date") {
					DatePicker(
						isRecurringTemplate ? "Start Date" : "Date",
						selection: $date,
						displayedComponents: [.date, .hourAndMinute]
					)
					.labelsHidden()
				}
			}

			if isRecurringTemplate {
				EditorSection("Recurrence") {
					EditorFieldRow("Frequency") {
						Picker("Frequency", selection: $recurrenceFrequency) {
							ForEach(RecurrenceFrequency.allCases) { frequency in
								Text(frequency.displayName).tag(frequency)
							}
						}
						.labelsHidden()
					}

					Toggle("Set end date", isOn: $hasRecurrenceEndDate)
					if hasRecurrenceEndDate {
						EditorFieldRow("End Date") {
							DatePicker(
								"End Date",
								selection: $recurrenceEndDate,
								displayedComponents: [.date, .hourAndMinute]
							)
							.labelsHidden()
						}
					}

					if !recurrenceRangeIsValid {
						Label("End date must be after the recurrence start date.", systemImage: "exclamationmark.triangle.fill")
							.font(.caption.weight(.medium))
							.foregroundStyle(.orange)
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
		.onAppear {
			note = transaction.note
			amountText = String(format: "%.2f", abs(transaction.amount))
			date = isRecurringTemplate ? transaction.startDate : transaction.date
			recurrenceFrequency = transaction.frequency
			if let endDate = transaction.endDate {
				hasRecurrenceEndDate = true
				recurrenceEndDate = endDate
			} else {
				hasRecurrenceEndDate = false
				recurrenceEndDate = date
			}
		}
	}

	private func save() {
		guard let rawAmount = amountValue else {
			saveErrorMessage = "Enter a valid amount."
			return
		}

		guard recurrenceRangeIsValid else {
			saveErrorMessage = "End date must be after the recurrence start date."
			return
		}

		if isRecurringTemplate {
			updateRecurringTemplate(rawAmount: rawAmount)
		} else if let counterpart = transferCounterpart(for: transaction) {
			updateTransferPair(counterpart: counterpart, rawAmount: rawAmount)
		} else {
			updateSingleTransaction(rawAmount: rawAmount)
		}

		do {
			try modelContext.save()
			dismiss()
		} catch {
			saveErrorMessage = error.localizedDescription
		}
	}

	private func updateRecurringTemplate(rawAmount: Double) {
		transaction.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
		transaction.amount = abs(rawAmount)
		transaction.frequency = recurrenceFrequency
		transaction.startDate = date
		transaction.date = date
		transaction.endDate = hasRecurrenceEndDate ? recurrenceEndDate : nil
		if transaction.nextOccurrenceDate < date {
			transaction.nextOccurrenceDate = date
		}
	}

	private func updateSingleTransaction(rawAmount: Double) {
		let oldAmount = transaction.amount
		let newAmount = signedAmount(for: transaction.type, rawAmount: rawAmount)
		transaction.amount = newAmount
		transaction.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
		transaction.date = date
		transaction.account?.balance += (newAmount - oldAmount)
	}

	private func updateTransferPair(counterpart: Transaction, rawAmount: Double) {
		let transferOut = transaction.type == .transferOut ? transaction : counterpart
		let transferIn = transaction.type == .transferIn ? transaction : counterpart

		let oldOutAmount = transferOut.amount
		let oldInAmount = transferIn.amount
		let amount = abs(rawAmount)
		let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

		transferOut.amount = -amount
		transferIn.amount = amount
		transferOut.note = trimmedNote
		transferIn.note = trimmedNote
		transferOut.date = date
		transferIn.date = date

		transferOut.account?.balance += (transferOut.amount - oldOutAmount)
		transferIn.account?.balance += (transferIn.amount - oldInAmount)
	}

	private func transferCounterpart(for transaction: Transaction) -> Transaction? {
		guard let transferGroupID = transaction.transferGroupID else { return nil }
		return allTransactions.first {
			$0.transferGroupID == transferGroupID && $0.id != transaction.id
		}
	}

	private func signedAmount(for type: TransactionKind, rawAmount: Double) -> Double {
		switch type {
		case .expense, .transferOut:
			return -abs(rawAmount)
		case .income, .transferIn:
			return abs(rawAmount)
		}
	}
}

#Preview {
	EditTransactionView(
		transaction: Transaction(
			amount: -42.5,
			note: "Coffee",
			date: .now,
			type: .expense,
			account: Account(name: "Checking", category: .checking, balance: 1000)
		)
	)
	.modelContainer(PreviewData.shared.modelContainer)
}
