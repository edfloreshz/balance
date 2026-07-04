//
//  TransferDirection.swift
//  Balance
//
//  Created by Eduardo Flores on 04/07/26.
//

enum TransferDirection: String, CaseIterable, Identifiable {
	case send
	case request
	
	var id: Self { self }
	
	var displayName: String {
		switch self {
		case .send: return "Send"
		case .request: return "Request"
		}
	}
}
