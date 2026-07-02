//
//  AddTransactionMode.swift
//  Balance
//
//  Created by Eduardo Flores on 02/07/26.
//

enum AddTransactionMode: String, Identifiable {
	case oneTime
	case recurring
	
	var id: String { rawValue }
}
