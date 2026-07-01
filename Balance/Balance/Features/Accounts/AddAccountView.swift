import SwiftData
import SwiftUI

struct AddAccountView: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.modelContext) private var modelContext
	
	let onSave: (Account) -> Void
	
	@State private var name = ""
	@State private var icon = ""
	@State private var category: Category
	@State private var openingBalanceText = ""
	@State private var currency = "USD"
	@State private var isArchived = false
	@State private var saveErrorMessage: String?
	
	init(selectedCategory: Category, onSave: @escaping (Account) -> Void) {
		self.onSave = onSave
		_category = State(initialValue: selectedCategory)
	}
	
	private var openingBalance: Double? {
		if openingBalanceText.isEmpty {
			return 0
		}
		
		return Double(openingBalanceText)
	}
	
	private var trimmedName: String {
		name.trimmingCharacters(in: .whitespacesAndNewlines)
	}
	
	private var trimmedIcon: String {
		icon.trimmingCharacters(in: .whitespacesAndNewlines)
	}
	
	private var normalizedCurrency: String {
		let value = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
		return value.isEmpty ? "USD" : value
	}
	
	private var canSave: Bool {
		!trimmedName.isEmpty && openingBalance != nil
	}
	
	var body: some View {
		EditorSheet(
			title: "New Account",
			subtitle: "Create an account with a category, opening balance, and currency."
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
				}
				
				EditorFieldRow("Currency") {
					TextField("USD", text: $currency)
#if os(iOS)
						.textInputAutocapitalization(.characters)
#endif
						.textFieldStyle(.roundedBorder)
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
			
			Button("Save") {
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
	}
	
	private func save() {
		guard let openingBalance else {
			saveErrorMessage = "Enter a valid opening balance."
			return
		}
		
		let account = Account(
			name: trimmedName,
			icon: trimmedIcon,
			category: category,
			balance: openingBalance,
			currency: normalizedCurrency,
			isArchived: isArchived
		)
		
		modelContext.insert(account)
		
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
	AddAccountView(selectedCategory: .checking) { _ in }
		.modelContainer(PreviewData.shared.modelContainer)
}
