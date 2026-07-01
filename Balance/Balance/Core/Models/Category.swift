//
//  Category.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//
import Foundation
import SwiftUI

enum Category: String, Codable, CaseIterable, Identifiable {
	case savings, creditCard, checking, investment, loan, cash, other
	
	var id: Self {
		self
	}
	
	var name: String {
		switch self {
		case .savings: return "Savings"
		case .creditCard: return "Credit Card"
		case .checking: return "Checking"
		case .investment: return "Investment"
		case .loan: return "Loan"
		case .cash: return "Cash"
		case .other: return "Other"
		}
	}
	
	var icon: String {
		switch self {
		case .savings: return "💵"
		case .creditCard: return "💳"
		case .checking: return "💰"
		case .investment: return "📈"
		case .loan: return "🏦"
		case .cash: return "👛"
		case .other: return "📁"
		}
	}
	
	var color: Color {
		switch self {
		case .savings: return .green
		case .creditCard: return .red
		case .checking: return .blue
		case .investment: return .purple
		case .loan: return .orange
		case .cash: return .mint
		case .other: return .gray
		}
	}
}
