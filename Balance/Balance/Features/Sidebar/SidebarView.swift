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
	@Binding var selection: SidebarSelection

	var body: some View {
		List(selection: $selection) {
			Section {
				NavigationLink(value: SidebarSelection.dashboard) {
					Label("Dashboard", systemImage: "chart.xyaxis.line")
				}
				.tag(SidebarSelection.dashboard)
			}
			
			Section("Accounts") {
				ForEach(Category.allCases) { category in
					NavigationLink(value: SidebarSelection.category(category)) {
						CategoryRow(category: category)
					}
					.tag(SidebarSelection.category(category))
				}
			}
		}
	}
}

#Preview {
	@Previewable @State var selection: SidebarSelection = .dashboard

	SidebarView(selection: $selection)
}
