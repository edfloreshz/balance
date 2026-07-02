//
//  DashboardDailyFlowSummary.swift
//  Balance
//
//  Created by Eduardo Flores on 02/07/26.
//

import Foundation

struct DashboardDailyFlowSummary: Identifiable {
	let date: Date
	let income: Double
	let expense: Double
	
	var id: Date { date }
}
