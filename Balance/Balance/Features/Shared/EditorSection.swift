import SwiftUI

struct EditorSection<Content: View>: View {
	let title: String
	@ViewBuilder let content: Content

	init(_ title: String, @ViewBuilder content: () -> Content) {
		self.title = title
		self.content = content()
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			Text(title)
				.font(.headline)

			VStack(alignment: .leading, spacing: 14) {
				content
			}
		}
		.padding(18)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
		.overlay {
			RoundedRectangle(cornerRadius: 14, style: .continuous)
				.strokeBorder(.quaternary, lineWidth: 1)
		}
	}
}

#Preview {
	EditorSection<Text>("Account Details") {
		Text("Sample content")
	}
	.padding()
}
