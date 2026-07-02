//
//  AppPreferences.swift
//  Balance
//
//  Created by Eduardo Flores on 02/07/26.
//

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
