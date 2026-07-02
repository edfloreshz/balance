import SwiftUI

struct EditorFieldRow<Content: View>: View {
	let label: String
	@ViewBuilder let content: Content

	init(_ label: String, @ViewBuilder content: () -> Content) {
		self.label = label
		self.content = content()
	}

	var body: some View {
		#if os(macOS)
			VStack(alignment: .leading, spacing: 6) {
				Text(label)
					.font(.caption.weight(.medium))
					.foregroundStyle(.secondary)
				content
					.frame(maxWidth: .infinity, alignment: .leading)
			}
		#else
			HStack(alignment: .firstTextBaseline, spacing: 12) {
				Text(label)
					.foregroundStyle(.secondary)
				Spacer(minLength: 12)
				content
					.multilineTextAlignment(.trailing)
			}
		#endif
	}
}

#Preview {
	EditorFieldRow("Name") {
		TextField("Checking Account", text: .constant("Main Checking"))
		#if os(macOS)
			.textFieldStyle(.roundedBorder)
		#endif
	}
	.padding()
}
