//
//  DashboardCategoryBalanceSummary.swift
//  Balance
//
//  Created by Eduardo Flores on 02/07/26.
//

struct DashboardCategoryBalanceSummary: Identifiable {
	let category: Category
	let totalBalance: Double
	
	var id: Category { category }
}
