//
//  TransactionEditorView.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import SwiftData
import SwiftUI

struct TransactionEditorView: View {
	private enum Mode {
		case add(account: Account, initialKind: TransactionKind, startsAsRecurring: Bool)
		case edit(transaction: Transaction)
	}
	
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss
	@Query(sort: \Account.name) private var accounts: [Account]
	@Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
	@Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
	@AppStorage(AppPreferences.dailyTransferLimitKey) private var dailyTransferLimit: Double = 0
	@AppStorage(AppPreferences.usesAutomaticTimeZoneKey) private var usesAutomaticTimeZone: Bool = true
	@AppStorage(AppPreferences.selectedTimeZoneIdentifierKey) private var selectedTimeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier
	
	private let mode: Mode
	
	@State private var note: String = ""
	@State private var amountText: String = ""
	@State private var date: Date = .now
	@State private var selectedKind: TransactionKind
	@State private var destinationAccountID: UUID?
	@State private var isRecurring: Bool = false
	@State private var recurrenceFrequency: RecurrenceFrequency = .monthly
	@State private var hasRecurrenceStartDate: Bool = false
	@State private var recurrenceStartDate: Date = .now
	@State private var hasRecurrenceEndDate: Bool = false
	@State private var recurrenceEndDate: Date = .now
	@State private var saveErrorMessage: String?
	
	init(
		account: Account,
		initialKind: TransactionKind = .expense,
		startsAsRecurring: Bool = false
	) {
		self.mode = .add(
			account: account,
			initialKind: initialKind,
			startsAsRecurring: startsAsRecurring
		)
		_selectedKind = State(initialValue: initialKind)
		_isRecurring = State(initialValue: startsAsRecurring)
	}
	
	init(transaction: Transaction) {
		self.mode = .edit(transaction: transaction)
		_selectedKind = State(initialValue: transaction.type)
		_note = State(initialValue: transaction.note)
		_amountText = State(initialValue: MoneyInputFormatter.format(abs(transaction.amount)))
		_date = State(initialValue: transaction.isRecurringTemplate ? transaction.startDate : transaction.date)
		_recurrenceFrequency = State(initialValue: transaction.frequency)
		if let endDate = transaction.endDate {
			_hasRecurrenceEndDate = State(initialValue: true)
			_recurrenceEndDate = State(initialValue: endDate)
		} else {
			_hasRecurrenceEndDate = State(initialValue: false)
			_recurrenceEndDate = State(initialValue: transaction.isRecurringTemplate ? transaction.startDate : transaction.date)
		}
	}
	
	private var isEditing: Bool {
		if case .edit = mode { return true }
		return false
	}
	
	private var transactionToEdit: Transaction? {
		guard case let .edit(transaction) = mode else { return nil }
		return transaction
	}
	
	private var currentAccount: Account? {
		switch mode {
		case let .add(account, _, _):
			return account
		case let .edit(transaction):
			return transaction.account
		}
	}
	
	private var currencyCode: String {
		currentAccount?.currency ?? "USD"
	}
	
	private var editorTitle: String {
		isEditing ? "Edit Transaction" : "New Transaction"
	}
	
	private var editorSubtitle: String {
		if isEditing {
			return "Update amount, note, and schedule details."
		}
		return "Add income, expense, or transfers for \(currentAccount?.name ?? "this account")."
	}
	
	private var effectiveKind: TransactionKind {
		isEditing ? (transactionToEdit?.type ?? selectedKind) : selectedKind
	}
	
	private var isRecurringTemplateEditing: Bool {
		transactionToEdit?.isRecurringTemplate == true
	}
	
	private var amountValue: Double? {
		MoneyInputFormatter.parse(amountText)
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
		!isEditing && effectiveKind == .transferOut
	}
	
	private var availableDestinationAccounts: [Account] {
		guard let sourceAccountID = currentAccount?.id else { return [] }
		return accounts
			.filter { $0.id != sourceAccountID && !$0.isArchived }
			.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
	}
	
	private var selectedDestinationAccount: Account? {
		guard let destinationAccountID else { return nil }
		return availableDestinationAccounts.first(where: { $0.id == destinationAccountID })
	}
	
	private var effectiveRecurrenceStartDate: Date {
		if isEditing {
			return date
		}
		return hasRecurrenceStartDate ? recurrenceStartDate : date
	}
	
	private var recurrenceRangeIsValid: Bool {
		if isEditing {
			return !isRecurringTemplateEditing || !hasRecurrenceEndDate || recurrenceEndDate >= effectiveRecurrenceStartDate
		}
		return !isRecurring || !hasRecurrenceEndDate || recurrenceEndDate >= effectiveRecurrenceStartDate
	}
	
	private var transferredAmountForSelectedDay: Double {
		transactions
			.filter {
				$0.type == .transferOut
				&& calendar.isDate($0.date, inSameDayAs: date)
				&& ($0.recurrenceFrequencyRawValue == nil || $0.recurrenceSeriesID != nil)
			}
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
		guard amountValue != nil, recurrenceRangeIsValid else { return false }
		
		if isTransfer {
			return selectedDestinationAccount != nil
		}
		return true
	}
	
	var body: some View {
		EditorSheet(
			title: editorTitle,
			subtitle: editorSubtitle,
			confirmLabel: "Save",
			onCancel: { dismiss() },
			onConfirm: { save() }
		) {
			if !isEditing, let currentAccount {
				EditorSection("Account") {
					HStack(spacing: 14) {
						ZStack {
							Circle()
								.fill(currentAccount.category.color.opacity(0.16))
								.frame(width: 44, height: 44)
							
							Text(currentAccount.icon.isEmpty ? currentAccount.category.icon : currentAccount.icon)
								.font(.title3)
						}
						
						VStack(alignment: .leading, spacing: 3) {
							Text(currentAccount.name)
								.font(.headline)
							Text(currentAccount.category.name)
								.font(.subheadline)
								.foregroundStyle(.secondary)
						}
						
						Spacer()
						
						Text(currentAccount.balance, format: .currency(code: currentAccount.currency))
							.font(.headline.weight(.semibold))
							.monospacedDigit()
					}
				}
			}
			
			EditorSection("Transaction Details") {
				EditorFieldRow("Type") {
					if isEditing {
						Text(effectiveKind.displayName)
							.frame(maxWidth: .infinity, alignment: .leading)
					} else {
						Picker("Type", selection: $selectedKind) {
							Text("Expense").tag(TransactionKind.expense)
							Text("Income").tag(TransactionKind.income)
							Text("Transfer").tag(TransactionKind.transferOut)
						}
						.pickerStyle(.segmented)
					}
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
#if os(macOS)
							.textFieldStyle(.roundedBorder)
#endif
							.onChange(of: amountText) { _, newValue in
								let sanitized = MoneyInputFormatter.sanitize(newValue)
								if sanitized != newValue {
									amountText = sanitized
								}
							}
							.onSubmit {
								if let amountValue {
									amountText = MoneyInputFormatter.format(abs(amountValue))
								}
							}
						
						Text(currencyCode)
							.font(.subheadline.weight(.medium))
							.foregroundStyle(.secondary)
					}
				}
				
				EditorFieldRow("Note") {
					TextField("Description", text: $note)
#if os(macOS)
						.textFieldStyle(.roundedBorder)
#endif
				}
				
				EditorFieldRow(isRecurringTemplateEditing ? "Start Date" : "Date") {
					DatePicker(
						isRecurringTemplateEditing ? "Start Date" : "Date",
						selection: $date,
						displayedComponents: [.date, .hourAndMinute]
					)
					.labelsHidden()
				}
			}
			
			if isEditing {
				if isRecurringTemplateEditing {
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
			} else {
				EditorSection("Recurrence") {
					Toggle("Repeat transaction", isOn: $isRecurring)
					
					if isRecurring {
						EditorFieldRow("Frequency") {
							Picker("Frequency", selection: $recurrenceFrequency) {
								ForEach(RecurrenceFrequency.allCases) { frequency in
									Text(frequency.displayName).tag(frequency)
								}
							}
							.labelsHidden()
						}
						
						Toggle("Set start date", isOn: $hasRecurrenceStartDate)
						if hasRecurrenceStartDate {
							EditorFieldRow("Start Date") {
								DatePicker(
									"Start Date",
									selection: $recurrenceStartDate,
									displayedComponents: [.date, .hourAndMinute]
								)
								.labelsHidden()
							}
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
			}
			
			if let amountValue {
				EditorSection("Preview") {
					HStack {
						Text(previewLabel)
							.foregroundStyle(.secondary)
						Spacer()
						Text(
							previewAmount(amountValue),
							format: .currency(code: currencyCode)
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
						Text(transferredAmountForSelectedDay, format: .currency(code: currencyCode))
							.monospacedDigit()
					}
					
					HStack {
						Text("Projected total")
							.foregroundStyle(.secondary)
						Spacer()
						Text(projectedTransferTotal, format: .currency(code: currencyCode))
							.monospacedDigit()
							.foregroundStyle(exceedsDailyTransferLimit ? .orange : .primary)
					}
					
					HStack {
						Text("Daily limit")
							.foregroundStyle(.secondary)
						Spacer()
						Text(dailyTransferLimit, format: .currency(code: currencyCode))
							.monospacedDigit()
					}
					
					if exceedsDailyTransferLimit {
						Label("Warning: this transfer exceeds your daily limit.", systemImage: "exclamationmark.triangle.fill")
							.font(.caption.weight(.medium))
							.foregroundStyle(.orange)
					}
				}
			}
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
			guard !isEditing else { return }
			if isTransfer, destinationAccountID == nil {
				destinationAccountID = availableDestinationAccounts.first?.id
			}
			recurrenceStartDate = date
			recurrenceEndDate = date
		}
		.onChange(of: selectedKind) { _, kind in
			guard !isEditing else { return }
			if kind == .transferOut, destinationAccountID == nil {
				destinationAccountID = availableDestinationAccounts.first?.id
			}
		}
		.onChange(of: date) { _, newDate in
			guard !isEditing else { return }
			if !hasRecurrenceStartDate {
				recurrenceStartDate = newDate
			}
			if !hasRecurrenceEndDate {
				recurrenceEndDate = newDate
			}
		}
		.onChange(of: hasRecurrenceStartDate) { _, hasStartDate in
			guard !isEditing else { return }
			if !hasStartDate {
				recurrenceStartDate = date
			}
		}
		.onChange(of: hasRecurrenceEndDate) { _, hasEndDate in
			guard !isEditing else { return }
			if !hasEndDate {
				recurrenceEndDate = date
			}
		}
	}
	
	private var previewLabel: String {
		switch effectiveKind {
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
		switch effectiveKind {
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
		switch effectiveKind {
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
		
		guard recurrenceRangeIsValid else {
			saveErrorMessage = "End date must be after the recurrence start date."
			return
		}
		
		if isEditing {
			saveEditedTransaction(rawAmount: rawAmount)
		} else {
			saveNewTransaction(rawAmount: rawAmount)
		}
		
		if saveErrorMessage != nil { return }
		
		do {
			try modelContext.save()
			dismiss()
		} catch {
			saveErrorMessage = error.localizedDescription
		}
	}
	
	private func saveNewTransaction(rawAmount: Double) {
		guard let account = currentAccount else {
			saveErrorMessage = "Couldn't find the source account."
			return
		}
		
		if isTransfer {
			guard let destinationAccount = selectedDestinationAccount else {
				saveErrorMessage = "Select a destination account."
				return
			}
			
			let transferAmount = abs(rawAmount)
			if isRecurring {
				let recurring = Transaction(
					amount: transferAmount,
					note: note,
					type: .transferOut,
					frequency: recurrenceFrequency,
					startDate: effectiveRecurrenceStartDate,
					endDate: hasRecurrenceEndDate ? recurrenceEndDate : nil,
					account: account,
					relatedAccount: destinationAccount
				)
				modelContext.insert(recurring)
				tryProcessRecurringNow(for: recurring)
				if saveErrorMessage != nil { return }
			} else {
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
			}
		} else {
			let amount = effectiveKind == .expense ? -abs(rawAmount) : abs(rawAmount)
			let type: TransactionKind = effectiveKind == .expense ? .expense : .income
			
			if isRecurring {
				let recurring = Transaction(
					amount: abs(rawAmount),
					note: note,
					type: type,
					frequency: recurrenceFrequency,
					startDate: effectiveRecurrenceStartDate,
					endDate: hasRecurrenceEndDate ? recurrenceEndDate : nil,
					account: account
				)
				modelContext.insert(recurring)
				tryProcessRecurringNow(for: recurring)
				if saveErrorMessage != nil { return }
			} else {
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
		}
	}
	
	private func saveEditedTransaction(rawAmount: Double) {
		guard let transaction = transactionToEdit else {
			saveErrorMessage = "Couldn't find the transaction to edit."
			return
		}
		
		if transaction.isRecurringTemplate {
			updateRecurringTemplate(transaction: transaction, rawAmount: rawAmount)
		} else if let counterpart = transferCounterpart(for: transaction) {
			updateTransferPair(transaction: transaction, counterpart: counterpart, rawAmount: rawAmount)
		} else {
			updateSingleTransaction(transaction: transaction, rawAmount: rawAmount)
		}
	}
	
	private func updateRecurringTemplate(transaction: Transaction, rawAmount: Double) {
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
	
	private func updateSingleTransaction(transaction: Transaction, rawAmount: Double) {
		let oldAmount = transaction.amount
		let newAmount = signedAmount(for: transaction.type, rawAmount: rawAmount)
		transaction.amount = newAmount
		transaction.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
		transaction.date = date
		transaction.account?.balance += (newAmount - oldAmount)
	}
	
	private func updateTransferPair(
		transaction: Transaction,
		counterpart: Transaction,
		rawAmount: Double
	) {
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
	
	private func tryProcessRecurringNow(for recurring: Transaction) {
		do {
			try RecurringTransactionProcessor.processDueTransactions(
				context: modelContext,
				recurringTransactions: [recurring],
				until: .now,
				calendar: calendar
			)
		} catch {
			saveErrorMessage = error.localizedDescription
		}
	}
}

#Preview("New") {
	TransactionEditorView(
		account: Account(name: "Chase Checking", icon: "🏦", category: .checking, balance: 1250.42)
	)
	.modelContainer(PreviewData.shared.modelContainer)
}

#Preview("Edit") {
	TransactionEditorView(
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
