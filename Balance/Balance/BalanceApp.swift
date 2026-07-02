//
//  BalanceApp.swift
//  Balance
//
//  Created by Eduardo Flores on 02/07/26.
//

import SwiftUI
import SwiftData

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
