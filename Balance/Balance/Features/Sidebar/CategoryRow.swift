//
//  AccountRow.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import SwiftUI

struct CategoryRow: View {
	@State var category: Category
	
    var body: some View {
		HStack {
			Text(category.icon)
			Text(category.name)
		}
    }
}

#Preview {
	CategoryRow(category: .savings)
}
