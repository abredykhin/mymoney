import Foundation

@MainActor
@Observable
final class IncomeInputViewModel {
    private(set) var rawDigits: String = ""

    private static let maxDigits = 8
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "$"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }()

    var intValue: Int { Int(rawDigits) ?? 0 }

    var displayAmount: String {
        guard !rawDigits.isEmpty, let value = Int(rawDigits) else { return "$0" }
        return Self.formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    func handleKey(_ key: String) {
        switch key {
        case "⌫":
            if !rawDigits.isEmpty { rawDigits.removeLast() }
        case ".":
            break // integers only
        default:
            guard let _ = Int(key) else { return }
            // Suppress leading zero
            if rawDigits.isEmpty && key == "0" { return }
            guard rawDigits.count < Self.maxDigits else { return }
            rawDigits.append(contentsOf: key)
        }
    }
}
