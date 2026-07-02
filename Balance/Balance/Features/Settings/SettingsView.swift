//
//  SettingsView.swift
//  Balance
//
//  Created by Eduardo Flores on 02/07/26.
//

import SwiftUI

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

#Preview {
	SettingsView()
}
