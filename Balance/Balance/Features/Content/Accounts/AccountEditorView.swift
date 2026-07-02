import SwiftData
import SwiftUI

struct AccountEditorView: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.modelContext) private var modelContext
	@AppStorage(AppPreferences.globalCurrencyCodeKey) private var globalCurrencyCode: String = AppPreferences.defaultGlobalCurrencyCode
	
	private let accountToEdit: Account?
	let onSave: (Account) -> Void
	
	@State private var name = ""
	@State private var icon = ""
	@State private var category: Category
	@State private var openingBalanceText = ""
	@State private var currency = ""
	@State private var isArchived = false
	@State private var saveErrorMessage: String?
	
	init(selectedCategory: Category, onSave: @escaping (Account) -> Void) {
		self.accountToEdit = nil
		self.onSave = onSave
		_category = State(initialValue: selectedCategory)
	}

	init(account: Account, onSave: @escaping (Account) -> Void = { _ in }) {
		self.accountToEdit = account
		self.onSave = onSave
		_name = State(initialValue: account.name)
		_icon = State(initialValue: account.icon)
		_category = State(initialValue: account.category)
		_openingBalanceText = State(initialValue: MoneyInputFormatter.format(account.balance))
		_currency = State(initialValue: account.currency)
		_isArchived = State(initialValue: account.isArchived)
	}

	private var isEditing: Bool {
		accountToEdit != nil
	}
	
	private var openingBalance: Double? {
		if openingBalanceText.isEmpty {
			return 0
		}
		
		return MoneyInputFormatter.parse(openingBalanceText)
	}
	
	private var trimmedName: String {
		name.trimmingCharacters(in: .whitespacesAndNewlines)
	}
	
	private var trimmedIcon: String {
		icon.trimmingCharacters(in: .whitespacesAndNewlines)
	}
	
	private var normalizedCurrency: String {
		let value = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
		return value.isEmpty ? globalCurrencyCode : value
	}
	
	private var canSave: Bool {
		!trimmedName.isEmpty && openingBalance != nil
	}
	
	var body: some View {
		EditorSheet(
			title: isEditing ? "Edit Account" : "New Account",
			subtitle: isEditing
				? "Update account details, balance, and currency."
				: "Create an account with a category, opening balance, and currency."
		) {
			EditorSection("Account Details") {
				EditorFieldRow("Name") {
					TextField("Checking Account", text: $name)
						.textFieldStyle(.roundedBorder)
				}
				
				EditorFieldRow("Icon") {
					HStack(spacing: 12) {
						TextField(category.icon, text: $icon)
							.textFieldStyle(.roundedBorder)
						Text(trimmedIcon.isEmpty ? category.icon : trimmedIcon)
							.font(.title2)
							.frame(width: 32)
					}
				}
				
				EditorFieldRow("Category") {
					Picker("Category", selection: $category) {
						ForEach(Category.allCases) { category in
							Text("\(category.icon) \(category.name)").tag(category)
						}
					}
					.labelsHidden()
					.frame(maxWidth: .infinity, alignment: .leading)
				}
			}
			
			EditorSection("Balance") {
				EditorFieldRow("Opening Balance") {
					TextField("0.00", text: $openingBalanceText)
#if os(iOS)
						.keyboardType(.decimalPad)
#endif
						.textFieldStyle(.roundedBorder)
						.onChange(of: openingBalanceText) { _, newValue in
							let sanitized = MoneyInputFormatter.sanitize(newValue, allowsNegative: true)
							if sanitized != newValue {
								openingBalanceText = sanitized
							}
						}
						.onSubmit {
							if let openingBalance {
								openingBalanceText = MoneyInputFormatter.format(openingBalance)
							}
						}
				}
				
				EditorFieldRow("Currency") {
					CurrencyPickerField(currencyCode: $currency)
				}
			}
			
			EditorSection("Options") {
				Toggle("Archive account", isOn: $isArchived)
					.toggleStyle(.switch)
			}
		} actions: {
			Button("Cancel") {
				dismiss()
			}
			
			Button(isEditing ? "Update" : "Save") {
				save()
			}
			.keyboardShortcut(.defaultAction)
			.disabled(!canSave)
		}
		.alert(
			"Couldn't Save Account",
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
			AppPreferences.synchronizeAutomaticTimeZoneIfNeeded()
			if currency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
				currency = globalCurrencyCode
			}
		}
	}
	
	private func save() {
		guard let openingBalance else {
			saveErrorMessage = "Enter a valid opening balance."
			return
		}

		let account: Account
		if let accountToEdit {
			accountToEdit.name = trimmedName
			accountToEdit.icon = trimmedIcon
			accountToEdit.category = category
			accountToEdit.balance = openingBalance
			accountToEdit.currency = normalizedCurrency
			accountToEdit.isArchived = isArchived
			account = accountToEdit
		} else {
			account = Account(
				name: trimmedName,
				icon: trimmedIcon,
				category: category,
				balance: openingBalance,
				currency: normalizedCurrency,
				isArchived: isArchived
			)
			modelContext.insert(account)
		}
		
		do {
			try modelContext.save()
			onSave(account)
			dismiss()
		} catch {
			saveErrorMessage = error.localizedDescription
		}
	}
}

#Preview {
	AccountEditorView(selectedCategory: .checking) { _ in }
		.modelContainer(PreviewData.shared.modelContainer)
}
