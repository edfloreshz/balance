import SwiftData
import SwiftUI

enum AppPreferences {
	static let usesAutomaticTimeZoneKey = "settings.usesAutomaticTimeZone"
	static let selectedTimeZoneIdentifierKey = "settings.selectedTimeZoneIdentifier"
	static let dailyTransferLimitKey = "settings.dailyTransferLimit"
	static let globalCurrencyCodeKey = "settings.globalCurrencyCode"
	
	static var defaultGlobalCurrencyCode: String {
		Locale.autoupdatingCurrent.currency?.identifier ?? "USD"
	}
	
	static var availableCurrencyCodes: [String] {
		Locale.commonISOCurrencyCodes.sorted {
			currencyDisplayName(for: $0).localizedCaseInsensitiveCompare(currencyDisplayName(for: $1)) == .orderedAscending
		}
	}
	
	static func currencyDisplayName(for code: String, locale: Locale = .autoupdatingCurrent) -> String {
		locale.localizedString(forCurrencyCode: code) ?? code
	}
	
	static func effectiveTimeZone(
		usesAutomaticTimeZone: Bool,
		selectedTimeZoneIdentifier: String
	) -> TimeZone {
		if usesAutomaticTimeZone {
			return .autoupdatingCurrent
		}
		
		return TimeZone(identifier: selectedTimeZoneIdentifier) ?? .autoupdatingCurrent
	}
	
	static func synchronizeAutomaticTimeZoneIfNeeded(defaults: UserDefaults = .standard) {
		if defaults.object(forKey: usesAutomaticTimeZoneKey) == nil {
			defaults.set(true, forKey: usesAutomaticTimeZoneKey)
		}
		
		if defaults.object(forKey: dailyTransferLimitKey) == nil {
			defaults.set(0.0, forKey: dailyTransferLimitKey)
		}
		
		if defaults.object(forKey: selectedTimeZoneIdentifierKey) == nil {
			defaults.set(TimeZone.autoupdatingCurrent.identifier, forKey: selectedTimeZoneIdentifierKey)
		}
		
		if defaults.object(forKey: globalCurrencyCodeKey) == nil {
			defaults.set(defaultGlobalCurrencyCode, forKey: globalCurrencyCodeKey)
		}
		
		let usesAutomatic = defaults.bool(forKey: usesAutomaticTimeZoneKey)
		if usesAutomatic {
			defaults.set(TimeZone.autoupdatingCurrent.identifier, forKey: selectedTimeZoneIdentifierKey)
		}
	}
}

@main struct Balance: App {
	init() {
		AppPreferences.synchronizeAutomaticTimeZoneIfNeeded()
	}
	
	var body: some Scene {
		WindowGroup {
			MasterView()
		}
		.modelContainer(for: [Account.self, Transaction.self])
	}
}

struct MasterView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.scenePhase) private var scenePhase
	@AppStorage(AppPreferences.usesAutomaticTimeZoneKey) private var usesAutomaticTimeZone: Bool = true
	@AppStorage(AppPreferences.selectedTimeZoneIdentifierKey) private var selectedTimeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier
	@Query(sort: \Transaction.date, order: .reverse) private var recurringTransactions: [Transaction]
	
	@State var selectedCategory: Category = .savings
	@State private var sidebarSelection: SidebarSelection = .dashboard
	@State var selectedAccount: Account?
	@State private var accountSearchText: String = ""
	@State private var transactionSearchText: String = ""
	@State private var showingAddAccount = false
	@State private var showingAddTransaction = false
	@State private var showingSettings = false
	@State private var addTransactionInitialKind: TransactionKind = .expense
	@State private var recurringSyncErrorMessage: String?
	@State private var accountDeletionErrorMessage: String?
	@State private var showingDeleteAccountConfirmation = false
	@State private var showingEditAccount: Bool = false
	
	private var timeZone: TimeZone {
		AppPreferences.effectiveTimeZone(
			usesAutomaticTimeZone: usesAutomaticTimeZone,
			selectedTimeZoneIdentifier: selectedTimeZoneIdentifier
		)
	}

	private var searchPrompt: String {
		selectedAccount == nil ? "Search accounts" : "Search transactions"
	}

	private var activeSearchText: Binding<String> {
		Binding(
			get: { selectedAccount == nil ? accountSearchText : transactionSearchText },
			set: { newValue in
				if selectedAccount == nil {
					accountSearchText = newValue
				} else {
					transactionSearchText = newValue
				}
			}
		)
	}

	var body: some View {
		Group {
			if case .category = sidebarSelection {
				NavigationSplitView {
					SidebarView(selection: $sidebarSelection)
						.navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 320)
						.toolbar(content: sidebarToolbarContent)
				} content: {
					ContentView(
						selectedCategory: $selectedCategory,
						selectedAccount: $selectedAccount,
						searchText: $accountSearchText
					) {
						showingAddAccount = true
					}
					.toolbar(content: contentToolbarContent)
					.navigationSplitViewColumnWidth(min: 300, ideal: 380, max: 520)
				} detail: {
					DetailView(
						selectedAccount: $selectedAccount,
						showingEditAccount: $showingEditAccount,
						searchText: $transactionSearchText
					)
					.toolbar(content: detailToolbarContent)
				}
				.searchable(text: activeSearchText, placement: .toolbar, prompt: searchPrompt)
			} else {
				NavigationSplitView {
					SidebarView(selection: $sidebarSelection)
						.toolbar(content: sidebarToolbarContent)
						.navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 320)
				} detail: {
					DashboardView()
				}
			}
		}
		.sheet(isPresented: $showingAddAccount) {
			AddAccountView(selectedCategory: selectedCategory) { account in
				selectedCategory = account.category
				sidebarSelection = .category(account.category)
				selectedAccount = account
			}
		}
		.sheet(isPresented: $showingAddTransaction) {
			if let selectedAccount {
				AddTransactionView(account: selectedAccount, initialKind: addTransactionInitialKind)
			}
		}
		.sheet(isPresented: $showingSettings) {
			SettingsView()
		}
		.onAppear {
			AppPreferences.synchronizeAutomaticTimeZoneIfNeeded()
			processRecurringTransactionsIfNeeded()
		}
		.onChange(of: selectedCategory) { _, newCategory in
			if case .category = sidebarSelection {
				sidebarSelection = .category(newCategory)
			}
		}
		.onChange(of: sidebarSelection) { _, newSelection in
			switch newSelection {
			case .dashboard:
				selectedAccount = nil
			case .category(let category):
				selectedCategory = category
			}
		}
		.onChange(of: scenePhase) { _, newPhase in
			if newPhase == .active {
				processRecurringTransactionsIfNeeded()
			}
		}
		.alert(
			"Couldn't Process Recurring Transactions",
			isPresented: Binding(
				get: { recurringSyncErrorMessage != nil },
				set: { if !$0 { recurringSyncErrorMessage = nil } }
			)
		) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(recurringSyncErrorMessage ?? "Something went wrong.")
		}
		.confirmationDialog(
			"Delete Account?",
			isPresented: $showingDeleteAccountConfirmation,
			titleVisibility: .visible
		) {
			Button("Delete Account", role: .destructive) {
				deleteSelectedAccount()
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			if let selectedAccount {
				Text("This will permanently delete \(selectedAccount.name) and all of its transactions.")
			}
		}
		.alert(
			"Couldn't Delete Account",
			isPresented: Binding(
				get: { accountDeletionErrorMessage != nil },
				set: { if !$0 { accountDeletionErrorMessage = nil } }
			)
		) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(accountDeletionErrorMessage ?? "Something went wrong.")
		}
	}
	
	@ToolbarContentBuilder
	private func sidebarToolbarContent() -> some ToolbarContent {
		ToolbarItem(placement: .secondaryAction) {
			Button {
				showingSettings = true
			} label: {
				Image(systemName: "gearshape")
			}
			.accessibilityLabel("Settings")
		}
	}
	
	@ToolbarContentBuilder
	private func contentToolbarContent() -> some ToolbarContent {
		
		ToolbarItem(placement: .automatic) {
			Button {
				showingEditAccount = true
			} label: {
				Label("Edit Account", systemImage: "pencil")
			}
			.help("Edit Account")
			.disabled(selectedAccount == nil)
		}
		ToolbarItem(placement: .confirmationAction) {
			Button(role: .destructive) {
				showingDeleteAccountConfirmation = selectedAccount != nil
			} label: {
				Label("Delete Account", systemImage: "trash")
			}
			.help("Delete Account")
			.disabled(selectedAccount == nil)
		}
		ToolbarSpacer()
		ToolbarItem(placement: .automatic) {
			Button {
				addTransactionInitialKind = .transferOut
				showingAddTransaction = selectedAccount != nil
			} label: {
				Label("Transfer from this account", systemImage: "arrow.left.arrow.right")
			}
			.help("Transfer from this account")
			.disabled(selectedAccount == nil)
		}
		ToolbarItem(placement: .primaryAction) {
			Button {
				showingAddAccount = true
			} label: {
				Image(systemName: "plus")
			}
			.help("Add Account")
		}
	}
	
	@ToolbarContentBuilder
	private func detailToolbarContent() -> some ToolbarContent {
		ToolbarItem(placement: .primaryAction) {
			Button {
				addTransactionInitialKind = .expense
				showingAddTransaction = selectedAccount != nil
			} label: {
				Image(systemName: "plus")
			}
			.help("Add Transaction")
			.disabled(selectedAccount == nil)
		}
	}
	
	private func processRecurringTransactionsIfNeeded() {
		var calendar = Calendar.autoupdatingCurrent
		calendar.timeZone = timeZone
		let recurringTemplates = recurringTransactions.filter { $0.isRecurringTemplate }
		
		do {
			try RecurringTransactionProcessor.processDueTransactions(
				context: modelContext,
				recurringTransactions: recurringTemplates,
				until: .now,
				calendar: calendar
			)
		} catch {
			recurringSyncErrorMessage = error.localizedDescription
		}
	}

	private func deleteSelectedAccount() {
		guard let selectedAccount else { return }
		
		showingEditAccount = false
		showingAddTransaction = false
		modelContext.delete(selectedAccount)
		
		do {
			try modelContext.save()
			self.selectedAccount = nil
		} catch {
			accountDeletionErrorMessage = error.localizedDescription
		}
	}
}

struct SettingsView: View {
	@Environment(\.dismiss) private var dismiss
	@AppStorage(AppPreferences.dailyTransferLimitKey) private var dailyTransferLimit: Double = 0
	@AppStorage(AppPreferences.usesAutomaticTimeZoneKey) private var usesAutomaticTimeZone: Bool = true
	@AppStorage(AppPreferences.selectedTimeZoneIdentifierKey) private var selectedTimeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier
	@AppStorage(AppPreferences.globalCurrencyCodeKey) private var globalCurrencyCode: String = AppPreferences.defaultGlobalCurrencyCode
	@State private var dailyTransferLimitText: String = ""
	
	private var selectedTimeZone: TimeZone {
		AppPreferences.effectiveTimeZone(
			usesAutomaticTimeZone: usesAutomaticTimeZone,
			selectedTimeZoneIdentifier: selectedTimeZoneIdentifier
		)
	}
	
	var body: some View {
		EditorSheet(
			title: "Settings",
			subtitle: "Configure transfer limits and timezone behavior."
		) {
			EditorSection("Transfers") {
				EditorFieldRow("Global Currency") {
					CurrencyPickerField(currencyCode: $globalCurrencyCode)
				}
				
				EditorFieldRow("Daily Limit") {
					HStack(spacing: 10) {
						TextField("No limit", text: $dailyTransferLimitText)
#if os(iOS)
							.keyboardType(.decimalPad)
#endif
							.textFieldStyle(.roundedBorder)
							.onChange(of: dailyTransferLimitText) { _, newValue in
								let normalized = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
								if normalized.isEmpty {
									dailyTransferLimit = 0
									return
								}
								
								if let parsedValue = Double(normalized), parsedValue >= 0 {
									dailyTransferLimit = parsedValue
								}
							}
						
						Text(globalCurrencyCode)
							.font(.subheadline.weight(.medium))
							.foregroundStyle(.secondary)
					}
				}
				
				Text("Set to 0 or leave empty to disable transfer limit warnings.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			
			EditorSection("Timezone") {
				Toggle("Use device timezone automatically", isOn: $usesAutomaticTimeZone)
					.onChange(of: usesAutomaticTimeZone) { _, isEnabled in
						if isEnabled {
							selectedTimeZoneIdentifier = TimeZone.autoupdatingCurrent.identifier
						}
					}
				
				EditorFieldRow("Timezone") {
					Picker("Timezone", selection: $selectedTimeZoneIdentifier) {
						ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { identifier in
							Text(identifier).tag(identifier)
						}
					}
					.labelsHidden()
					.disabled(usesAutomaticTimeZone)
				}
				
				Text("Current timezone: \(selectedTimeZone.identifier)")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		} actions: {
			Button("Done") {
				dismiss()
			}
			.keyboardShortcut(.defaultAction)
		}
		.onAppear {
			AppPreferences.synchronizeAutomaticTimeZoneIfNeeded()
			if dailyTransferLimit > 0 {
				dailyTransferLimitText = String(format: "%.2f", dailyTransferLimit)
			} else {
				dailyTransferLimitText = ""
			}
		}
	}
}

#Preview("Unselected") {
	MasterView(selectedAccount: nil)
		.modelContainer(PreviewData.shared.modelContainer)
}

#Preview("Selected") {
	MasterView(selectedAccount: Account.sampleData[0])
		.modelContainer(PreviewData.shared.modelContainer)
}
