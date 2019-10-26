//
//  Document.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 21/10/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa

fileprivate let kObjects = "objects"
fileprivate let kLabels = "userDefinedLabels"

protocol DocumentDelegate {
	func projectDidLoad()
	func projectChanged()
}

class Document: NSDocument {
	
	// our document will be package-based later
	var fileWrapper: FileWrapper!
	
	/// This is posted whenever the document has finished indexing its class labels
	static let labelsIndexed = NSNotification.Name(rawValue: "labelsWereIndexed")
	
	var allLabels: [String] {
		get {
			return labels + customLabels
		}
	}
	
	// detected labels
	var labels: [String] = []
	// user-defined laabels
	var customLabels: [String] = []
	
	var objects: [PhotoAnnotation] = []
	var delegate: DocumentDelegate!
	var isLoading = false

	override init() {
	    super.init()
		// Add your subclass-specific initialization here.
	}

	override class var autosavesInPlace: Bool {
		return true
	}

	override func makeWindowControllers() {
		// Returns the Storyboard that contains your Document window.
		let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
		let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! NSWindowController
		self.addWindowController(windowController)
		
		// allow the view controller to access our objects array
		windowController.contentViewController?.representedObject = self
	}
	
	override func revertToSaved(_ sender: Any?) {
		delegate?.projectChanged()
		super.revertToSaved(sender)
	}
	
	// MARK: Save / Read

	override func data(ofType typeName: String) throws -> Data {
		let encoder = NSKeyedArchiver(requiringSecureCoding: true)
		
		encoder.encode(objects, forKey: kObjects)
		encoder.encode(customLabels, forKey: kLabels)
		encoder.finishEncoding()
		
		return encoder.encodedData
	}

	override func read(from data: Data, ofType typeName: String) throws {
		guard let decoder = try? NSKeyedUnarchiver(forReadingFrom: data) else {
			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
		}
		
		isLoading = true

		DispatchQueue.global(qos: .userInitiated).async {
			guard let objects = decoder.decodeObject(of: [NSArray.self, PhotoAnnotation.self], forKey: kObjects) as? [PhotoAnnotation] else {
				return
			}
			
			if let labels = decoder.decodeObject(of: [NSArray.self, NSString.self], forKey: kLabels) as? [String] {
				self.customLabels = labels
			}
			
			DispatchQueue.main.async {
				self.objects = objects
				self.delegate.projectDidLoad()
				self.isLoading = false
			}
		}
	}
	
	func exportCreateML(url: URL, completion: ((Bool) -> Void)? = nil) {
		
		let fm = FileManager.default
		let objects = self.objects
		
		DispatchQueue.global(qos: .userInitiated).async {
			
			// create a directory to store our photos
			do {
				try fm.createDirectory(at: url, withIntermediateDirectories: false, attributes: .none)
			} catch {
				completion?(false)
				return
			}
			
			var json: [[String: Any]] = []
			
			// export our photos
			for (i, object) in objects.enumerated() {
				let photoName = "photo-\(i).png"
				let photoData = object.photo.tiffRepresentation!.bitmap!.png
				
				let filename = url.appendingPathComponent(photoName).path
				
				fm.createFile(atPath: filename, contents: photoData, attributes: .none)
				
				// log its annotations
				var objectEntry: [String: Any] = ["image": photoName]
				var annotations: [[String: Any]] = []
				
				for annotation in object.annotations {
					annotations.append(["label": annotation.label, "coordinates": annotation.json])
				}
				
				objectEntry["annotations"] = annotations
				json.append(objectEntry)
			}
			
			// write the annotations file
			let annotationsPath = url.appendingPathComponent("annotations.json").path
			
			guard let annotationsData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
				
				completion?(false)
				return
			}
			
			fm.createFile(atPath: annotationsPath, contents: annotationsData, attributes: .none)
			
			completion?(true)
		}
	}
	
	// MARK: Background Actions
	
	func indexLabels() {
		let objects = self.objects
		let udl = customLabels
		
		DispatchQueue.global(qos: .background).async {
			var labels: [String] = []
			
			for object in objects {
				for annotation in object.annotations {
					let label = annotation.label
					
					// exclude unlabled items and user-defined labels
					guard label != "No Label" && !label.isEmpty && !udl.contains(label) else {
						continue
					}
					
					// only include valid labels
					if !labels.contains(label) {
						labels.append(label)
					}
				}
			}
			
			DispatchQueue.main.async {
				self.labels = labels
				NotificationCenter.default.post(name: Document.labelsIndexed, object: self, userInfo: nil)
			}
		}
	}
}

