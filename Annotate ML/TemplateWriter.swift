//
//  TemplateWriter.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 07/07/2020.
//  Copyright © 2020 Emily Blackwell. All rights reserved.
//

import Foundation


// MARK: Error

struct TemplateWriterError: Error {
	
	enum ErrorType: String {
		case missing = "missing template file"
		case write = "write error"
	}
	
	var filename: String?
	var type: ErrorType
	
	var localizedDescription: String {
		return "Error: \(self.type.rawValue) | File: \(filename ?? "n/a")"
	}
}

// MARK: Template Writer

class TemplateWriter {
	
	typealias EditHandler = (String) -> String
	
	static func writeFile(filename: String, extension ext: String, toUrl url: URL, edit: EditHandler? = nil) throws {
		
		let bundle = Bundle.main
		let fm = FileManager.default
		
		// Open our template file
		guard let fileUrl = bundle.url(forResource: filename, withExtension: ext),
			let data = try? Data(contentsOf: fileUrl),
			var contents = String(data: data, encoding: .utf8) else {
				throw TemplateWriterError(filename: nil, type: .missing)
		}
		
		// Apply edits
		if let edits = edit {
			contents = edits(contents)
		}
		
		// Write our template file
		let filename = url.appendingPathComponent("\(filename).\(ext)").path
		let fileData = contents.data(using: .utf8)
		
		do {
			if fm.fileExists(atPath: filename) {
				try fm.removeItem(atPath: filename)
			}
			
			fm.createFile(atPath: filename, contents: fileData, attributes: [:])
		}
		catch {
			throw TemplateWriterError(filename: filename, type: .write)
		}
	}
}
