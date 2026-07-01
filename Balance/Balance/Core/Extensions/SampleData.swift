//
//  SampleData.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import Foundation
import SwiftData

@MainActor
class PreviewData {
	static let shared = PreviewData()
	let modelContainer: ModelContainer
	var context: ModelContext {
		modelContainer.mainContext
	}
	
	private init() {
		let schema = Schema([
			Account.self,
			Transaction.self,
		])
		
		let modelConfiguration = ModelConfiguration(
			schema: schema,
			isStoredInMemoryOnly: true
		)
		
		do {
			modelContainer = try ModelContainer(
				for: schema,
				configurations: [modelConfiguration]
			)
			
			let accounts = Account.sampleData
			for account in accounts {
				context.insert(account)
			}

			
			let transactions = Transaction.sampleData(for: accounts)
			for transaction in transactions {
				context.insert(transaction)
			}

			
			try context.save()
		} catch {
			fatalError("Could not create ModelContainer: \(error)")
		}
	}
}
