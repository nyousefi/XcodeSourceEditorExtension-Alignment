//
//  SourceEditorCommand.swift
//  Alignment
//
//  Created by Atsushi Kiwaki on 6/16/16.
//  Copyright © 2016 Atsushi Kiwaki. All rights reserved.
//

import Foundation
import XcodeKit

class SourceEditorCommand: NSObject, XCSourceEditorCommand {

	func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void) {
		// Implement your command here, invoking the completion handler when done. Pass it nil on success, and an NSError on failure.
		guard let selection = invocation.buffer.selections.firstObject as? XCSourceTextRange else {
			completionHandler(NSError(domain: "SampleExtension", code: -1, userInfo: [NSLocalizedDescriptionKey: "None selection"]))
			return
		}

		let def = UserDefaults(suiteName: "\(Bundle.main.object(forInfoDictionaryKey: "TeamIdentifierPrefix") as? String ?? "")Alignment-for-Xcode")
		let isEnableAssignment = def?.object(forKey: "KEY_ENABLE_ASSIGNMENT") as? Bool ?? true
		let isEnableTypeDeclaration = def?.object(forKey: "KEY_ENABLE_TYPE_DECLARATION") as? Bool ?? false

		do {
			// if isEnableTypeDeclaration {
				try alignTypeDeclaration(invocation: invocation, selection: selection)
			// }

			if isEnableAssignment {
				try alignAssignment(invocation: invocation, selection: selection)
			}
		} catch {
			completionHandler(NSError(domain: "SampleExtension", code: -1, userInfo: [NSLocalizedDescriptionKey: ""]))
			return
		}

		completionHandler(nil)
	}

	func alignAssignment(invocation: XCSourceEditorCommandInvocation, selection: XCSourceTextRange) throws {
		var regex: NSRegularExpression?
		regex = try NSRegularExpression(pattern: "[^+^%^*^^^<^>^&^|^?^=^-](\\s*)(=)[^=]", options: .caseInsensitive)

		let alignPosition = invocation.buffer.lines.enumerated().map { i, line -> Int in
			guard i >= selection.start.line && i <= selection.end.line,
				let line = line as? String,
				let result = regex?.firstMatch(in: line, options: .reportProgress, range: NSRange(location: 0, length: line.count)) else {
					return 0
			}
			return result.range(at: 1).location
			}.max()

		for index in selection.start.line ... selection.end.line {
			guard let line = invocation.buffer.lines[index] as? String,
				let result = regex?.firstMatch(in: line, options: .reportProgress, range: NSRange(location: 0, length: line.count)) else {
					continue
			}

			let range = result.range(at: 2)

			guard range.location != NSNotFound else {
				continue
			}

			let repeatCount = alignPosition! - range.location + 1

			guard repeatCount != 0 else {
				continue
			}

			let whiteSpaces = String(repeating: " ", count: abs(repeatCount))
			if repeatCount > 0 {
				invocation.buffer.lines.replaceObject(at: index, with: line.replacingOccurrences(of: "=", with: "\(whiteSpaces)=", options: [.regularExpression], range: line.startIndex..<line.index(line.startIndex, offsetBy: range.location+1)))
			} else {
				invocation.buffer.lines.replaceObject(at: index, with: line.replacingOccurrences(of: "\(whiteSpaces)=", with: "="))
			}
		}
	}

	func alignTypeDeclaration(invocation: XCSourceEditorCommandInvocation, selection: XCSourceTextRange) throws {
		var regex: NSRegularExpression?
		regex = try NSRegularExpression(pattern: "^([^:]+?)(:)", options: .caseInsensitive)

		let alignPosition1 = invocation.buffer.lines.enumerated().map { i, line -> Int in
			guard
				i >= selection.start.line,
				i <= selection.end.line,
				let line = line as? String
				else { return 0 }

			let scanner = Scanner(string: line)
			scanner.scanUpToCharacters(from: CharacterSet(charactersIn: "=("), into: nil)

			guard
				let result = regex?.firstMatch(in: line, options: .reportProgress, range: NSRange(location: 0, length: scanner.scanLocation))
				else { return 0 }

			return result.range(at: 2).location
			}.max()

		for index in selection.start.line ... selection.end.line {
			guard let line = invocation.buffer.lines[index] as? NSString else {
				continue
			}

			let scanner = Scanner(string: line as String)
			scanner.scanUpToCharacters(from: CharacterSet(charactersIn: "=("), into: nil)

			let range = line.range(of: "^([^:]+?)(:)", options: [.regularExpression], range: NSRange(location: 0, length: scanner.scanLocation))

			guard range.location != NSNotFound else {
				continue
			}

			let repeatCount = alignPosition1! - NSMaxRange(range) + 2

			guard repeatCount != 0 else {
				continue
			}

			let whiteSpaces = String(repeating: " ", count: abs(repeatCount))
			let replacementRange = NSRange(location: NSMaxRange(range) - 1, length: 1)

			if repeatCount > 0 {
				invocation.buffer.lines.replaceObject(at: index, with: line.replacingCharacters(in: replacementRange, with: "\(whiteSpaces):"))
			} else {
				invocation.buffer.lines.replaceObject(at: index, with: line.replacingOccurrences(of: "\(whiteSpaces):", with: ":"))
			}
		}
	}
}
