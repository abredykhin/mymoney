//
//  NSObject+Extensions.swift
//  mymoney
//
//  Created by Anton Bredykhin on 2/19/24.
//

import Foundation

struct Logger {
    /// Type of logs available
    private enum LogType: String {
        /// To log a message
        case debug
        /// To log an info
        case info
        /// To log a warning
        case warning
        /// To log an error
        case error
    }
    
    static func d(_ message: String,
           fileName: String = #file,
           functionName: String = #function,
           lineNumber: Int = #line) {
        self.log(type: .debug, message: message, file: fileName, line: lineNumber, function: functionName)
    }
    
    static func i(_ message: String,
           fileName: String = #file,
           functionName: String = #function,
           lineNumber: Int = #line) {
        self.log(type: .info, message: message, file: fileName, line: lineNumber, function: functionName)
    }
    
    static func w(_ message: String,
           fileName: String = #file,
           functionName: String = #function,
           lineNumber: Int = #line) {
        self.log(type: .warning, message: message, file: fileName, line: lineNumber, function: functionName)
    }
    
    static func e(_ message: String,
           fileName: String = #file,
           functionName: String = #function,
           lineNumber: Int = #line) {
        self.log(type: .error, message: message, file: fileName, line: lineNumber, function: functionName)
    }
    
    private static func log(type logType: LogType = .debug, message: String, file: String = #file, line: Int = #line, function: String = #function) {
        var logMessage = ""
        
        switch logType{
        case .debug:
            logMessage += "🐛"
        case .info:
            logMessage += "ℹ️"
        case .warning:
            logMessage += "⚠️"
        case .error:
            logMessage += "🔥"
        }
        
        let fileName = file.components(separatedBy: "/").last ?? ""
        logMessage += " \(fileName) - \(function): \(message)"
        Swift.print(logMessage)
    }
}

