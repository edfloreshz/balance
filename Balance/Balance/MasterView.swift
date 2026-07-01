import SwiftData
import SwiftUI

@main struct Balance: App {
	var body: some Scene {
		WindowGroup {
			MasterView()
		}
		.modelContainer(for: [Account.self, Transaction.self])
	}
}

struct MasterView: View {
	@State var selectedCategory: Category = .savings
	@State var selectedAccount: Account?
	@State private var showingAddAccount = false
	@State private var showingAddTransaction = false

	var body: some View {
		NavigationSplitView {
			SidebarView(selectedCategory: $selectedCategory)
		} content: {
			ContentView(
				selectedCategory: $selectedCategory,
				selectedAccount: $selectedAccount,
				onAddAccount: {
					showingAddAccount = true
				}
			)
		} detail: {
			DetailView(selectedAccount: $selectedAccount)
		}
		.navigationSplitViewStyle(.prominentDetail)
		.toolbar(content: toolbarContent)
		.sheet(isPresented: $showingAddAccount) {
			AddAccountView(selectedCategory: selectedCategory) { account in
				selectedCategory = account.category
				selectedAccount = account
			}
		}
		.sheet(isPresented: $showingAddTransaction) {
			if let selectedAccount {
				AddTransactionView(account: selectedAccount)
			}
		}
	}
	
	@ToolbarContentBuilder
	private func toolbarContent() -> some ToolbarContent {
		ToolbarItem(placement: .primaryAction) {
			Menu {
				Button {
					showingAddAccount = true
				} label: {
					Label("New Account", systemImage: "building.columns")
				}
				
				Button {
					showingAddTransaction = selectedAccount != nil
				} label: {
					Label("New Transaction", systemImage: "list.bullet.rectangle.portrait")
				}
				.disabled(selectedAccount == nil)
			} label: {
				Image(systemName: "plus")
			}
		}
	}
}

#Preview("Unselected") {
	MasterView(selectedAccount: nil)
		.modelContainer(PreviewData.shared.modelContainer)
}

#Preview("Selected") {
	MasterView(selectedAccount: Account.sampleData[0])
		.modelContainer(PreviewData.shared.modelContainer)
}
