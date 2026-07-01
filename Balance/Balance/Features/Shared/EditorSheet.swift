import SwiftUI

struct EditorSheet<Content: View, Actions: View>: View {
	let title: String
	let subtitle: String
	@ViewBuilder let content: Content
	@ViewBuilder let actions: Actions
	
	var body: some View {
		VStack(spacing: 0) {
			VStack(alignment: .leading, spacing: 6) {
				Text(title)
					.font(.title2.weight(.semibold))
				Text(subtitle)
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(.horizontal, 24)
			.padding(.top, 24)
			.padding(.bottom, 20)
			
			Divider()
			
			VStack(alignment: .leading, spacing: 20) {
				content
			}
			.padding(24)
			.frame(maxWidth: .infinity, alignment: .leading)
			
			Divider()
			
			HStack {
				Spacer()
				actions
			}
			.padding(.horizontal, 24)
			.padding(.vertical, 16)
		}
		.frame(minWidth: 540, idealWidth: 560, maxWidth: 620)
		.fixedSize(horizontal: false, vertical: true)
	}
}

#Preview {
	EditorSheet(
		title: "New Account",
		subtitle: "Create an account with a category, opening balance, and currency."
	) {
		EditorSection("Account Details") {
			EditorFieldRow("Name") {
				TextField("Checking Account", text: .constant("Main Checking"))
					.textFieldStyle(.roundedBorder)
			}
			EditorFieldRow("Category") {
				Text("Checking")
			}
		}
	} actions: {
		Button("Cancel") {}
		Button("Save") {}
	}
}
