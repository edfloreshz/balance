import SwiftData
import SwiftUI

struct AddTransactionView: View {
	let account: Account
	let initialKind: TransactionKind
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss
	@Query(sort: \Account.name) private var accounts: [Account]
	@Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
	@AppStorage(AppPreferences.dailyTransferLimitKey) private var dailyTransferLimit: Double = 0
	@AppStorage(AppPreferences.usesAutomaticTimeZoneKey) private var usesAutomaticTimeZone: Bool = true
	@AppStorage(AppPreferences.selectedTimeZoneIdentifierKey) private var selectedTimeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier
	
	@State private var note: String = ""
	@State private var amountText: String = ""
	@State private var date: Date = .now
	@State private var selectedKind: TransactionKind
	@State private var destinationAccountID: UUID?
	@State private var saveErrorMessage: String?
	
	init(account: Account, initialKind: TransactionKind = .expense) {
		self.account = account
		self.initialKind = initialKind
		_selectedKind = State(initialValue: initialKind)
	}
	
	private var amountValue: Double? {
		Double(amountText)
	}
	
	private var timeZone: TimeZone {
		AppPreferences.effectiveTimeZone(
			usesAutomaticTimeZone: usesAutomaticTimeZone,
			selectedTimeZoneIdentifier: selectedTimeZoneIdentifier
		)
	}
	
	private var calendar: Calendar {
		var calendar = Calendar.autoupdatingCurrent
		calendar.timeZone = timeZone
		return calendar
	}
	
	private var isTransfer: Bool {
		selectedKind == .transferOut
	}
	
	private var availableDestinationAccounts: [Account] {
		accounts
			.filter { $0.id != account.id && !$0.isArchived }
			.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
	}
	
	private var selectedDestinationAccount: Account? {
		guard let destinationAccountID else { return nil }
		return availableDestinationAccounts.first(where: { $0.id == destinationAccountID })
	}
	
	private var transferredAmountForSelectedDay: Double {
		transactions
			.filter { $0.type == .transferOut && calendar.isDate($0.date, inSameDayAs: date) }
			.reduce(0) { partialResult, transaction in
				partialResult + abs(transaction.amount)
			}
	}
	
	private var projectedTransferTotal: Double {
		guard isTransfer, let amountValue else { return transferredAmountForSelectedDay }
		return transferredAmountForSelectedDay + abs(amountValue)
	}
	
	private var exceedsDailyTransferLimit: Bool {
		dailyTransferLimit > 0 && isTransfer && projectedTransferTotal > dailyTransferLimit
	}
	
	private var canSave: Bool {
		if isTransfer {
			return amountValue != nil && selectedDestinationAccount != nil
		}
		return amountValue != nil
	}
	
	var body: some View {
		EditorSheet(
			title: "New Transaction",
			subtitle: "Add income, expense, or transfers for \(account.name)."
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
					Picker("Type", selection: $selectedKind) {
						Text("Expense").tag(TransactionKind.expense)
						Text("Income").tag(TransactionKind.income)
						Text("Transfer").tag(TransactionKind.transferOut)
					}
					.pickerStyle(.segmented)
				}
				
				if isTransfer {
					EditorFieldRow("To Account") {
						Picker("To Account", selection: Binding(
							get: { destinationAccountID },
							set: { destinationAccountID = $0 }
						)) {
							Text("Select account").tag(Optional<UUID>.none)
							ForEach(availableDestinationAccounts) { destination in
								Text(destination.name).tag(Optional(destination.id))
							}
						}
						.labelsHidden()
					}
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
						Text(previewLabel)
							.foregroundStyle(.secondary)
						Spacer()
						Text(
							previewAmount(amountValue),
							format: .currency(code: account.currency)
						)
						.font(.headline.weight(.semibold))
						.foregroundStyle(previewAmountColor)
						.monospacedDigit()
					}
					
					if let selectedDestinationAccount, isTransfer {
						HStack {
							Text("Receiving account")
								.foregroundStyle(.secondary)
							Spacer()
							Text(selectedDestinationAccount.name)
								.font(.subheadline.weight(.semibold))
						}
					}
				}
			}
			
			if isTransfer && dailyTransferLimit > 0 {
				EditorSection("Transfer Limit") {
					HStack {
						Text("Transferred today")
							.foregroundStyle(.secondary)
						Spacer()
						Text(transferredAmountForSelectedDay, format: .currency(code: account.currency))
							.monospacedDigit()
					}
					
					HStack {
						Text("Projected total")
							.foregroundStyle(.secondary)
						Spacer()
						Text(projectedTransferTotal, format: .currency(code: account.currency))
							.monospacedDigit()
							.foregroundStyle(exceedsDailyTransferLimit ? .orange : .primary)
					}
					
					HStack {
						Text("Daily limit")
							.foregroundStyle(.secondary)
						Spacer()
						Text(dailyTransferLimit, format: .currency(code: account.currency))
							.monospacedDigit()
					}
					
					if exceedsDailyTransferLimit {
						Label("Warning: this transfer exceeds your daily limit.", systemImage: "exclamationmark.triangle.fill")
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
		.environment(\.timeZone, timeZone)
		.onAppear {
			AppPreferences.synchronizeAutomaticTimeZoneIfNeeded()
			if isTransfer, destinationAccountID == nil {
				destinationAccountID = availableDestinationAccounts.first?.id
			}
		}
		.onChange(of: selectedKind) { _, kind in
			if kind == .transferOut, destinationAccountID == nil {
				destinationAccountID = availableDestinationAccounts.first?.id
			}
		}
	}
	
	private var previewLabel: String {
		switch selectedKind {
		case .expense:
			return "This will subtract"
		case .income:
			return "This will add"
		case .transferOut:
			return "This will move"
		case .transferIn:
			return "This will add"
		}
	}
	
	private var previewAmountColor: Color {
		switch selectedKind {
		case .expense:
			return .red
		case .income:
			return .green
		case .transferOut:
			return .blue
		case .transferIn:
			return .green
		}
	}
	
	private func previewAmount(_ amountValue: Double) -> Double {
		switch selectedKind {
		case .expense, .transferOut:
			return -abs(amountValue)
		case .income, .transferIn:
			return abs(amountValue)
		}
	}
	
	private func save() {
		guard let rawAmount = amountValue else {
			saveErrorMessage = "Enter a valid amount."
			return
		}
		
		if isTransfer {
			guard let destinationAccount = selectedDestinationAccount else {
				saveErrorMessage = "Select a destination account."
				return
			}
			
			let transferAmount = abs(rawAmount)
			let transferGroupID = UUID()
			
			let sourceTransaction = Transaction(
				amount: -transferAmount,
				note: note,
				date: date,
				type: .transferOut,
				transferGroupID: transferGroupID,
				account: account,
				relatedAccount: destinationAccount
			)
			
			let destinationTransaction = Transaction(
				amount: transferAmount,
				note: note,
				date: date,
				type: .transferIn,
				transferGroupID: transferGroupID,
				account: destinationAccount,
				relatedAccount: account
			)
			
			modelContext.insert(sourceTransaction)
			modelContext.insert(destinationTransaction)
			
			account.balance -= transferAmount
			destinationAccount.balance += transferAmount
		} else {
			let amount = selectedKind == .expense ? -abs(rawAmount) : abs(rawAmount)
			let type: TransactionKind = selectedKind == .expense ? .expense : .income
			
			let transaction = Transaction(
				amount: amount,
				note: note,
				date: date,
				type: type,
				account: account
			)
			modelContext.insert(transaction)
			account.balance += amount
		}
		
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
