//
//  AccountsView.swift
//  Balance
//
//  Created by Eduardo Flores on 01/07/26.
//

import SwiftUI

enum SidebarSelection: Hashable {
	case dashboard
	case category(Category)
}

struct SidebarView: View {
	@Bindable var viewModel: MasterViewModel
	
	private var sidebarSelection: Binding<SidebarSelection?> {
		Binding(
			get: { viewModel.sidebarSelection },
			set: { newValue in
				guard let newValue else { return }
				viewModel.sidebarSelection = newValue
			}
		)
	}

	var body: some View {
		List(selection: sidebarSelection) {
			Section {
				NavigationLink(value: SidebarSelection.dashboard) {
					Label("Dashboard", systemImage: "chart.xyaxis.line")
				}
				.tag(SidebarSelection.dashboard)
			}
			
			Section("Accounts") {
				ForEach(Category.allCases) { category in
					NavigationLink(value: SidebarSelection.category(category)) {
						CategoryView(category: category)
					}
					.tag(SidebarSelection.category(category))
				}
			}
		}
	}
}

#Preview {
	SidebarView(viewModel: MasterViewModel())
}
