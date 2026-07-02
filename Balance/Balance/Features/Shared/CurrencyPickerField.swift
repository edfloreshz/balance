import SwiftUI

struct CurrencyPickerField: View {
	@Binding var currencyCode: String

	var body: some View {
		Picker("Currency", selection: $currencyCode) {
			ForEach(AppPreferences.availableCurrencyCodes, id: \.self) { code in
				Text("\(AppPreferences.currencyDisplayName(for: code))").tag(code)
			}
		}
		.labelsHidden()
	}
}

#Preview {
	CurrencyPickerField(currencyCode: .constant("USD"))
}
