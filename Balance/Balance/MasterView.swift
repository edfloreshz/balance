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
	@State var selectedAccount: Account?
	@State private var showingAddAccount = false
	@State private var showingAddTransaction = false
	@State private var showingSettings = false
	@State private var addTransactionInitialKind: TransactionKind = .expense
	@State private var recurringSyncErrorMessage: String?
	
	private var timeZone: TimeZone {
		AppPreferences.effectiveTimeZone(
			usesAutomaticTimeZone: usesAutomaticTimeZone,
			selectedTimeZoneIdentifier: selectedTimeZoneIdentifier
		)
	}

	var body: some View {
		NavigationSplitView {
			SidebarView(selectedCategory: $selectedCategory)
		} content: {
			ContentView(
				selectedCategory: $selectedCategory,
				selectedAccount: $selectedAccount,
			) {
				showingAddAccount = true
			} onTransferFromAccount: { account in
				selectedCategory = account.category
				selectedAccount = account
				addTransactionInitialKind = .transferOut
				showingAddTransaction = true
			}
		} detail: {
			DetailView(selectedAccount: $selectedAccount)
		}
		.navigationSplitViewStyle(.prominentDetail)
		.toolbar(content: toolbarContent)
		.sheet(isPresented: $showingAddAccount) {
			AddAccountView(selectedCategory: selectedCategory) { account in
				selectedCategory = account.category
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
	}
	
	@ToolbarContentBuilder
	private func toolbarContent() -> some ToolbarContent {
		ToolbarItem(placement: .automatic) {
			Button {
				showingSettings = true
			} label: {
				Image(systemName: "gearshape")
			}
			.accessibilityLabel("Settings")
		}
		
		ToolbarItem(placement: .primaryAction) {
			Menu {
				Button {
					showingAddAccount = true
				} label: {
					Label("New Account", systemImage: "building.columns")
				}
				
				Button {
					addTransactionInitialKind = .expense
					showingAddTransaction = selectedAccount != nil
				} label: {
					Label("New Transaction", systemImage: "list.bullet.rectangle.portrait")
				}
				.disabled(selectedAccount == nil)
			} label: {
				Image(systemName: "plus")
			}
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
