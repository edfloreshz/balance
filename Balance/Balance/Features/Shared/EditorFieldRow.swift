import SwiftUI

struct EditorFieldRow<Content: View>: View {
	let label: String
	@ViewBuilder let content: Content
	
	init(_ label: String, @ViewBuilder content: () -> Content) {
		self.label = label
		self.content = content()
	}
	
	var body: some View {
		HStack(alignment: .center, spacing: 16) {
			Text(label)
				.foregroundStyle(.secondary)
				.frame(width: 110, alignment: .trailing)
			
			content
				.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}

#Preview {
	EditorFieldRow("Name") {
		TextField("Checking Account", text: .constant("Main Checking"))
			.textFieldStyle(.roundedBorder)
	}
	.padding()
}
