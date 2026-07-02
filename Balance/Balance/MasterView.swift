//
//  MasterView.swift
//  Balance
//
//  Created by Eduardo Flores on 02/07/26.
//

import SwiftData
import SwiftUI

struct MasterView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.scenePhase) private var scenePhase
	@AppStorage(AppPreferences.usesAutomaticTimeZoneKey) private var usesAutomaticTimeZone: Bool = true
	@AppStorage(AppPreferences.selectedTimeZoneIdentifierKey) private var selectedTimeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier
	@Query(sort: \Transaction.date, order: .reverse) private var recurringTransactions: [Transaction]
	
	@State private var viewModel = MasterViewModel()
	
	private var timeZone: TimeZone {
		AppPreferences.effectiveTimeZone(
			usesAutomaticTimeZone: usesAutomaticTimeZone,
			selectedTimeZoneIdentifier: selectedTimeZoneIdentifier
		)
	}

	var body: some View {
		@Bindable var viewModel = viewModel

		Group {
			if case .category = viewModel.sidebarSelection {
				NavigationSplitView {
					SidebarView(viewModel: viewModel)
						.navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 320)
						.toolbar(content: sidebarToolbarContent)
				} content: {
					ContentView(viewModel: viewModel)
					.toolbar(content: contentToolbarContent)
					.navigationSplitViewColumnWidth(min: 300, ideal: 380, max: 520)
				} detail: {
					DetailView(viewModel: viewModel)
					.toolbar(content: detailToolbarContent)
				}
				.searchable(text: $viewModel.activeSearchText, placement: .toolbar, prompt: viewModel.searchPrompt)
			} else {
				NavigationSplitView {
					SidebarView(viewModel: viewModel)
						.toolbar(content: sidebarToolbarContent)
						.navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 320)
				} detail: {
					DashboardView()
				}
			}
		}
		.sheet(isPresented: $viewModel.showingAddAccount) {
			AccountEditorView(selectedCategory: viewModel.selectedCategory) { account in
				viewModel.handleAccountCreated(account)
			}
		}
		.sheet(isPresented: $viewModel.showingAddTransaction) {
			if let selectedAccount = viewModel.selectedAccount {
				TransactionEditorView(account: selectedAccount, initialKind: viewModel.addTransactionInitialKind)
			}
		}
		.sheet(isPresented: $viewModel.showingSettings) {
			SettingsView()
		}
		.onAppear {
			AppPreferences.synchronizeAutomaticTimeZoneIfNeeded()
			processRecurringTransactionsIfNeeded()
		}
		.onChange(of: viewModel.selectedCategory) { _, _ in
			viewModel.synchronizeSidebarSelectionWithCategory()
		}
		.onChange(of: viewModel.sidebarSelection) { _, _ in
			viewModel.handleSidebarSelectionChange()
		}
		.onChange(of: scenePhase) { _, newPhase in
			if newPhase == .active {
				processRecurringTransactionsIfNeeded()
			}
		}
		.alert(
			"Couldn't Process Recurring Transactions",
			isPresented: Binding(
				get: { viewModel.recurringSyncErrorMessage != nil },
				set: { if !$0 { viewModel.recurringSyncErrorMessage = nil } }
			)
		) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(viewModel.recurringSyncErrorMessage ?? "Something went wrong.")
		}
		.confirmationDialog(
			"Delete Account?",
			isPresented: $viewModel.showingDeleteAccountConfirmation,
			titleVisibility: .visible
		) {
			Button("Delete Account", role: .destructive) {
				deleteSelectedAccount()
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			if let selectedAccount = viewModel.selectedAccount {
				Text("This will permanently delete \(selectedAccount.name) and all of its transactions.")
			}
		}
		.alert(
			"Couldn't Delete Account",
			isPresented: Binding(
				get: { viewModel.accountDeletionErrorMessage != nil },
				set: { if !$0 { viewModel.accountDeletionErrorMessage = nil } }
			)
		) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(viewModel.accountDeletionErrorMessage ?? "Something went wrong.")
		}
	}
	
	@ToolbarContentBuilder
	private func sidebarToolbarContent() -> some ToolbarContent {
		ToolbarItem(placement: .secondaryAction) {
			Button {
				viewModel.showingSettings = true
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
				viewModel.showingEditAccount = true
			} label: {
				Label("Edit Account", systemImage: "pencil")
			}
			.help("Edit Account")
			.disabled(viewModel.selectedAccount == nil)
		}
		ToolbarItem(placement: .confirmationAction) {
			Button(role: .destructive) {
				viewModel.requestSelectedAccountDeletion()
			} label: {
				Label("Delete Account", systemImage: "trash")
			}
			.help("Delete Account")
			.disabled(viewModel.selectedAccount == nil)
		}
		ToolbarSpacer()
		ToolbarItem(placement: .automatic) {
			Button {
				viewModel.showAddTransaction(initialKind: .transferOut)
			} label: {
				Label("Transfer from this account", systemImage: "arrow.left.arrow.right")
			}
			.help("Transfer from this account")
			.disabled(viewModel.selectedAccount == nil)
		}
		ToolbarItem(placement: .primaryAction) {
			Button {
				viewModel.showingAddAccount = true
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
				viewModel.showAddTransaction(initialKind: .expense)
			} label: {
				Image(systemName: "plus")
			}
			.help("Add Transaction")
			.disabled(viewModel.selectedAccount == nil)
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
			viewModel.recurringSyncErrorMessage = error.localizedDescription
		}
	}

	private func deleteSelectedAccount() {
		guard let selectedAccount = viewModel.selectedAccount else { return }
		
		viewModel.showingEditAccount = false
		viewModel.showingAddTransaction = false
		modelContext.delete(selectedAccount)
		
		do {
			try modelContext.save()
			viewModel.selectedAccount = nil
		} catch {
			viewModel.accountDeletionErrorMessage = error.localizedDescription
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
								let sanitized = MoneyInputFormatter.sanitize(newValue)
								if sanitized != newValue {
									dailyTransferLimitText = sanitized
									return
								}
								
								let normalized = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
								if normalized.isEmpty {
									dailyTransferLimit = 0
									return
								}
								
								if let parsedValue = MoneyInputFormatter.parse(normalized), parsedValue >= 0 {
									dailyTransferLimit = parsedValue
								}
							}
							.onSubmit {
								if dailyTransferLimit > 0 {
									dailyTransferLimitText = MoneyInputFormatter.format(dailyTransferLimit)
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
				dailyTransferLimitText = MoneyInputFormatter.format(dailyTransferLimit)
			} else {
				dailyTransferLimitText = ""
			}
		}
	}
}

#Preview("Unselected") {
	MasterView()
		.modelContainer(PreviewData.shared.modelContainer)
}

#Preview("Selected") {
	MasterView()
		.modelContainer(PreviewData.shared.modelContainer)
}
