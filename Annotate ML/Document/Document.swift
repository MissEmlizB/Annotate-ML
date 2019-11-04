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
fileprivate let kPhotoIndex = "photoIndex"

fileprivate let kPhotosDir = "Photos"
fileprivate let kThumbnailsDir = "Thumbnails"

protocol DocumentDelegate {
	func projectDidLoad()
	func projectChanged()
}

class Document: NSDocument {
	
	var fileWrapper: FileWrapper!
	var photosWrapper: FileWrapper!
	var thumbnailWrapper: FileWrapper!
	private var photoIndex: Int = 0
	
	var fileWasLoaded = false
	
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
		
		if !fileWasLoaded {
			// create our file structure
			fileWrapper = FileWrapper(directoryWithFileWrappers: [:])
			
			photosWrapper = FileWrapper(directoryWithFileWrappers: [:])
			photosWrapper.setFilename(kPhotosDir)
			
			thumbnailWrapper = FileWrapper(directoryWithFileWrappers: [:])
			thumbnailWrapper.setFilename(kThumbnailsDir)
			
			fileWrapper.addFileWrapper(photosWrapper)
			fileWrapper.addFileWrapper(thumbnailWrapper)
		}
	}

	override class var autosavesInPlace: Bool {
		return true
	}
	
	override func canAsynchronouslyWrite(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) -> Bool {
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
	
	override func write(to url: URL, ofType typeName: String) throws {
		
		// remove our old annotations file
		fileWrapper.removeFileWrapper(withFilename: "annotations")
		
		let encoder = NSKeyedArchiver(requiringSecureCoding: true)
		encoder.encode(objects, forKey: kObjects)
		encoder.encode(customLabels, forKey: kLabels)
		encoder.encode(photoIndex, forKey: kPhotoIndex)
		encoder.finishEncoding()
		
		// add our new annotations file
		let annotationsWrapper = FileWrapper(regularFileWithContents: encoder.encodedData)
		annotationsWrapper.setFilename("annotations")
		
		fileWrapper.addFileWrapper(annotationsWrapper)
		try? fileWrapper.write(to: url, options: .atomic, originalContentsURL: self.fileURL)
	}
	
	override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
		
		guard let annotationsWrapper = fileWrapper.fileWrappers?["annotations"],
			let data = annotationsWrapper.regularFileContents,
			let decoder = try? NSKeyedUnarchiver(forReadingFrom: data)
			else {
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
			
			let photoIndex = decoder.decodeInteger(forKey: kPhotoIndex)

			DispatchQueue.main.async {
				self.objects = objects
				self.photoIndex = photoIndex
				self.delegate.projectDidLoad()
				self.isLoading = false
			}
		}
		
		// set our wrappers
		self.fileWrapper = fileWrapper
		self.photosWrapper = fileWrapper.fileWrappers![kPhotosDir]
		self.thumbnailWrapper = fileWrapper.fileWrappers![kThumbnailsDir]
		
		// this file was loaded from an existing document
		self.fileWasLoaded = true
	}
	
	// MARK: Export
	
	func exportCreateML(url: URL, completion: ((Bool) -> Void)? = nil) {
		
		let wrapper = self.photosWrapper
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
			let projectLocation = self.fileURL
			let photosURL = projectLocation?.appendingPathComponent("Photos", isDirectory: true)
			
			// export our photos
			for object in objects {
				let photoName = object.photoFilename!
				let filename = url.appendingPathComponent(photoName).path
				
				if projectLocation != nil {
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
	
	// MARK: Package Actions
	
	private func photoAndThumbnailWrapper(for photo: NSImage, filename: String) -> [FileWrapper]? {
		
		guard let pngData = photo.tiffRepresentation?.bitmap?.png else {
				return nil
		}
		
		let photoWrapper = FileWrapper(regularFileWithContents: pngData)
		photoWrapper.setFilename(filename)

		// create a thumbnail for this photo
		
		guard let thumbnail = thumbnailify(photo: photo),
			let thumbnailData = thumbnail.tiffRepresentation?.bitmap?.png
			else {
			return nil
		}
		
		let thumbnailWrapper = FileWrapper(regularFileWithContents: thumbnailData)
		thumbnailWrapper.setFilename(filename)
		
		return [photoWrapper, thumbnailWrapper]
	}
	
	private func add(filename: String, wrappers: [FileWrapper], at start: Int = -1) {
	
		// create a new photo annotation object pointing to it
		let object = PhotoAnnotation(filename: filename)
		
		DispatchQueue.main.async {
			self.photosWrapper.addFileWrapper(wrappers[0])
			self.thumbnailWrapper.addFileWrapper(wrappers[1])
			
			if start != -1 {
				self.objects.insert(object, at: start)
			} else {
				self.objects.append(object)
			}
		}
	}
	
	func addPhotos(from urls: [URL], at start: Int = -1, available: ((Int) -> ())? = nil) {
		
		let index = photoIndex
		
		DispatchQueue.global(qos: .userInitiated).async {
			for (i, url) in urls.enumerated() {
				
				let filename = "Photo \(index + i).png"
				
				// copy the image data to our "Photos" directory
				guard let data = try? Data(contentsOf: url),
					let image = NSImage(data: data),
					let wrappers = self.photoAndThumbnailWrapper(for: image, filename: filename), wrappers.count == 2
					else {
					continue
				}
				
				self.add(filename: filename, wrappers: wrappers, at: start)
				
				// a new object is available!
				DispatchQueue.main.async {
					available?(i)
					self.photoIndex += urls.count
				}
			}
		}
	}
	
	func addPhotos(_ images: [NSImage], at start: Int = -1, available: ((Int) -> ())? = nil) {
		
		let index = photoIndex
		
		DispatchQueue.global(qos: .userInitiated).async {
			for (i, photo) in images.enumerated() {
					
				let filename = "Photo \(index + i).png"
					
				guard let wrappers = self.photoAndThumbnailWrapper(for: photo, filename: filename), wrappers.count == 2 else {
						continue
				}
					
				self.add(filename: filename, wrappers: wrappers, at: start)
				
				DispatchQueue.main.async {
					available?(i)
					self.photoIndex += images.count
				}
			}
		}
	}
	
	func removePhoto(at row: Int) {
		guard row >= 0 && row < objects.count else {
			return
		}
		
		// remove it from our objects list
		let filename = objects[row].photoFilename
		objects.remove(at: row)
		
		// and remove it from our package
		photosWrapper.removeFileWrapper(withFilename: filename!)
		thumbnailWrapper.removeFileWrapper(withFilename: filename!)
	}
	
	func getPhoto(for object: PhotoAnnotation?, isThumbnail: Bool = false) -> NSImage? {
		
		guard let object = object,
			let wrapper = isThumbnail ? thumbnailWrapper : photosWrapper
			else {
			return nil
		}
		
		let filename = object.photoFilename!
		
		guard let photoWrapper = wrapper.fileWrappers?[filename],
			let data = photoWrapper.regularFileContents,
			let photo = NSImage(data: data)
			else {
			return nil
		}
		
		return photo
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

