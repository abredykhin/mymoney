//
//  Dates.swift
//  Bablo
//
//  Created by Anton Bredykhin on 9/24/24.
//

import SwiftUI

// Helper method for date formatting
func formatDate(_ dateString: String, inputFormat: String = "yyyy-MM-dd'T'HH:mm:ss.SSSZ", outputFormat: DateFormatter.Style = .medium) -> String {
    let inputFormatter = DateFormatter()
    inputFormatter.dateFormat = inputFormat
    
    let outputFormatter = DateFormatter()
    outputFormatter.dateStyle = outputFormat
    
    if let date = inputFormatter.date(from: dateString) {
        return outputFormatter.string(from: date)
    } else {
        return dateString // Fallback if date conversion fails
    }
}
