//
//  Account+SampleData.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

extension Account {
	static var sampleData: [Account] {
		[
			.init(name: "BBVA", icon: "🏦", category: .savings),
			.init(name: "BBVA Oro", icon: "🏦", category: .creditCard),
			.init(name: "Banamex", icon: "🏦", category: .creditCard),
			.init(name: "Liverpool", icon: "🏦", category: .creditCard),
			.init(name: "Sears", icon: "🏦", category: .creditCard),
			.init(name: "Crypto", icon: "🏦", category: .investment)
		]
	}
}
