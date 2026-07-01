//
//  AccountsView.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import SwiftUI

struct SidebarView: View {
	@Binding var selectedCategory: Category

	var body: some View {
		List(selection: $selectedCategory) {
			ForEach(Category.allCases) { category in
				NavigationLink(value: category) {
					CategoryRow(category: category)
				}
				.tag(category)
			}
		}
    }
}

#Preview {
	@Previewable @State var selectedCategory: Category = .savings

	SidebarView(selectedCategory: $selectedCategory)
}
