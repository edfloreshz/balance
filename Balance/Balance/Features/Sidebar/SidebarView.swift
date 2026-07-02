//
//  AccountsView.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import SwiftUI

struct SidebarView: View {
	@Binding var selectedCategory: Category
	
	private var sidebarSelection: Binding<Category?> {
		Binding(
			get: { selectedCategory },
			set: { newValue in
				guard let newValue else { return }
				selectedCategory = newValue
			}
		)
	}

	var body: some View {
		List(selection: sidebarSelection) {
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
