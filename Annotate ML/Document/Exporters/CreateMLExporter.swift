//
//  CreateMLExporter.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 06/07/2020.
//  Copyright © 2020 Emily Blackwell. All rights reserved.
//

import Cocoa

class CreateMLExporter: DocumentExporter {
	
	weak var document: Document!
	
	init(document: Document) {
		self.document = document
	}
	
	/// (object: PhotoAnnotation, name: String)
	typealias AnnotationWriteHandler = (PhotoAnnotation, String) -> Void
	
	// MARK: Tasks
	
	func _exportCreateDirectory(url: URL, completion: CompletionHandler?) {
		
		let fm = FileManager.default
		
		// Create a directory to store our photos
		do {
			try fm.createDirectory(at: url, withIntermediateDirectories: false, attributes: .none)
		} catch {
			completion?(false)
			return
		}
	}
	
	/// Exports the photos to a directory
	/// - Parameters:
	///   - url: The selected URL for exporting
	///   - writeAnnotation: Called whenever we need to write annotations for the current object
	func _exportPhotos(url: URL, writeAnnotation: AnnotationWriteHandler) {
		
		let fm = FileManager.default
		let wrapper = self.document.photosWrapper
		
		let objects = self.document.objects
		let fileURL = self.document.fileURL
		
		let photosURL = fileURL?.appendingPathComponent("Photos", isDirectory: true)
		
		// Create our Photos directory
		let outputDirectory = url.appendingPathComponent("Photos")
		
		if fm.fileExists(atPath: outputDirectory.path) {
			try? fm.removeItem(at: outputDirectory)
		}
		
		try? fm.createDirectory(at: outputDirectory, withIntermediateDirectories: false, attributes: [:])
		
		// Copy/write our photos to it
		for object in objects {
			let photoName = object.photoFilename!
			let filename = outputDirectory
				.appendingPathComponent(photoName).path
            print(filename)

			if fileURL != nil {
				// if the project is already saved, we'll just copy
				// the files from our package to the selected folder
				
				let photoURL = photosURL!.appendingPathComponent(photoName)
				try? fm.copyItem(atPath: photoURL.path, toPath: filename)
				
			} else {
				
				// if not, we'll just create them
				guard let photoWrapper = wrapper?.fileWrappers?[photoName],
					let photoData = photoWrapper.regularFileContents,
					let photo = NSImage(data: photoData),
					let data = photo.tiffRepresentation?.bitmap?.png
					else {
						continue
				}
				
				fm.createFile(atPath: filename, contents: data, attributes: [:])
			}
			
			// log its annotations
			writeAnnotation(object, "Photos/\(photoName)")
		}
	}
	
	/// Writes the exported project's annotations file
	/// - Parameters:
	///   - url: The selected URL for exporting
	///   - completion: Export completion handler
	func _exportFile(url: URL, object: Any, completion: CompletionHandler?) {
		
		let fm = FileManager.default
		let json = object as! [[String: Any]]
		
		// write the annotations file
		let annotationsPath = url.appendingPathComponent("annotations.json").path
		
		guard let annotationsData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
			
			completion?(false)
			return
		}
		
		fm.createFile(atPath: annotationsPath, contents: annotationsData, attributes: .none)
		
		completion?(true)
	}
	
	/// Exports the object to a URL
	/// - Parameters:
	///   - url: The selected URL for exporting
	///   - completion: Export completion handler
	func _exportObjects(url: URL, completion: CompletionHandler?) {
		
		self._exportCreateDirectory(url: url, completion: completion)
		var json: [[String: Any]] = []
		
		// export our photos
		self._exportPhotos(url: url) { object, photoName in
			
			var objectEntry: [String: Any] = ["image": photoName]
			var annotations: [[String: Any]] = []
			
			for annotation in object.annotations {
				annotations.append([
					"label": annotation.label,
					"coordinates": annotation.json
				])
			}
			
			objectEntry["annotations"] = annotations
			json.append(objectEntry)
		}
		
		// Export our annotations file
		self._exportFile(url: url, object: json, completion: completion)
	}
	
	// MARK: Export
	
	func export(url: URL, completion: CompletionHandler?) {
		self._exportObjects(url: url, completion: completion)
	}
}
