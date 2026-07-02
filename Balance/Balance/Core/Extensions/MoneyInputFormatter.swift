import Foundation

enum MoneyInputFormatter {
	static func sanitize(_ input: String, allowsNegative: Bool = false, locale: Locale = .autoupdatingCurrent) -> String {
		let decimalSeparator = locale.decimalSeparator ?? "."
		let groupingSeparator = locale.groupingSeparator ?? ","
		let alternateDecimalSeparators = [".", ","].filter {
			$0 != decimalSeparator && $0 != groupingSeparator
		}
		
		var result = ""
		var didUseDecimalSeparator = false
		var didUseMinus = false
		
		for scalar in input.unicodeScalars {
			let character = Character(scalar)
			let string = String(character)
			
			if CharacterSet.decimalDigits.contains(scalar) {
				result.append(character)
				continue
			}
			
			if allowsNegative, string == "-", result.isEmpty, !didUseMinus {
				didUseMinus = true
				result.append(character)
				continue
			}
			
			if string == decimalSeparator || alternateDecimalSeparators.contains(string) {
				if !didUseDecimalSeparator {
					didUseDecimalSeparator = true
					result.append(contentsOf: decimalSeparator)
				}
				continue
			}
			
			if string == groupingSeparator, !didUseDecimalSeparator {
				result.append(character)
			}
		}
		
		return result
	}
	
	static func parse(_ input: String, locale: Locale = .autoupdatingCurrent) -> Double? {
		let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return nil }
		
		let formatter = numberFormatter(locale: locale)
		return formatter.number(from: trimmed)?.doubleValue
	}
	
	static func format(
		_ value: Double,
		minimumFractionDigits: Int = 2,
		maximumFractionDigits: Int = 2,
		locale: Locale = .autoupdatingCurrent
	) -> String {
		let formatter = numberFormatter(
			minimumFractionDigits: minimumFractionDigits,
			maximumFractionDigits: maximumFractionDigits,
			locale: locale
		)
		return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
	}
	
	private static func numberFormatter(
		minimumFractionDigits: Int = 0,
		maximumFractionDigits: Int = 2,
		locale: Locale = .autoupdatingCurrent
	) -> NumberFormatter {
		let formatter = NumberFormatter()
		formatter.locale = locale
		formatter.numberStyle = .decimal
		formatter.usesGroupingSeparator = true
		formatter.minimumFractionDigits = minimumFractionDigits
		formatter.maximumFractionDigits = maximumFractionDigits
		formatter.generatesDecimalNumbers = false
		formatter.isLenient = false
		return formatter
	}
}
