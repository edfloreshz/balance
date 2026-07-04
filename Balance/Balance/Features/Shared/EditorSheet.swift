import SwiftUI

struct EditorSheet<Content: View>: View {
	let title: String
	let subtitle: String
	let cancelLabel: String
	let confirmLabel: String
	let isConfirmDisabled: Bool
	let onCancel: () -> Void
	let onConfirm: () -> Void
	let content: Content

	init(
		title: String,
		subtitle: String,
		cancelLabel: String = "Cancel",
		confirmLabel: String,
		isConfirmDisabled: Bool = false,
		onCancel: @escaping () -> Void,
		onConfirm: @escaping () -> Void,
		@ViewBuilder content: () -> Content
	) {
		self.title = title
		self.subtitle = subtitle
		self.cancelLabel = cancelLabel
		self.confirmLabel = confirmLabel
		self.isConfirmDisabled = isConfirmDisabled
		self.onCancel = onCancel
		self.onConfirm = onConfirm
		self.content = content()
	}

	var body: some View {
		#if os(iOS)
		iOSBody
		#else
		macOSBody
		#endif
	}

	#if os(iOS)
	private var iOSBody: some View {
		NavigationStack {
			Form {
				Section {
					Text(subtitle)
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.listRowBackground(Color.clear)
						.listRowSeparator(.hidden)
				}
				content
			}
			.navigationTitle(title)
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button(cancelLabel, action: onCancel)
				}
				ToolbarItem(placement: .confirmationAction) {
					Button(confirmLabel, action: onConfirm)
						.disabled(isConfirmDisabled)
						.fontWeight(.semibold)
				}
			}
		}
	}
	#else
	private var macOSBody: some View {
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
			
			ScrollView {
				VStack(alignment: .leading, spacing: 20) {
					content
				}
				.padding(24)
				.frame(maxWidth: .infinity, alignment: .leading)
			}
			.frame(maxHeight: 480)
			
			Divider()
			
			HStack {
				Spacer()
				Button(cancelLabel, action: onCancel)
				Button(confirmLabel, action: onConfirm)
					.keyboardShortcut(.defaultAction)
					.disabled(isConfirmDisabled)
			}
			.padding(.horizontal, 24)
			.padding(.vertical, 16)
		}
		.frame(minWidth: 540, idealWidth: 560, maxWidth: 620)
	}
	#endif
}

#Preview {
	EditorSheet(
		title: "New Account",
		subtitle: "Create an account with a category, opening balance, and currency.",
		confirmLabel: "Save",
		onCancel: {},
		onConfirm: {}
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
	}
}
