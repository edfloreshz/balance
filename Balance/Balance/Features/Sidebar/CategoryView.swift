//
//  AccountRow.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import SwiftUI

struct CategoryView: View {
	@State var category: Category
	
    var body: some View {
		HStack {
			Text(category.icon)
			Text(category.name)
		}
    }
}

#Preview {
	CategoryView(category: .savings)
}
