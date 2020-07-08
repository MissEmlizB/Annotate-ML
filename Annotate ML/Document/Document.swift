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

fileprivate let CreateMLImageTypes = ["png", "jpg", "jpeg"]

protocol DocumentDelegate {
	func projectDidLoad(document: Document)
	func projectChanged(document: Document)
}

class Document: NSDocument {
	
	var fileWrapper: FileWrapper!
	var photosWrapper: FileWrapper!
	var thumbnailWrapper: FileWrapper!
	
	private var photoIndex: Int = 0
	private var indexingTask: DispatchWorkItem?
	
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
		
		self.hasUndoManager = true
		
		if !fileWasLoaded {
			// create our file structure
			fileWrapper = FileWrapper(directoryWithFileWrappers: [:])
			
			photosWrapper = FileWrapper(directoryWithFileWrappers: [:])
			photosWrapper.setFilename(kPhotosDir)
			
			thumbnailWrapper = FileWrapper(directoryWithFileWrappers: [:])
			thumbnailWrapper.setFilename(kThumbnailsDir)
			
			fileWrapper.addFileWrapper(photosWrapper, canOverwrite: true)
			fileWrapper.addFileWrapper(thumbnailWrapper, canOverwrite: true)
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
		let splitViewController = windowController.contentViewController as! SplitViewController
		
		splitViewController.document = self
	}
	
	override func revertToSaved(_ sender: Any?) {
		
		delegate?.projectChanged(document: self)
		super.revertToSaved(sender)
	}
	
	// MARK: Save / Read
	
	override func write(to url: URL, ofType typeName: String) throws {

		let encoder = NSKeyedArchiver(requiringSecureCoding: true)
		encoder.encode(objects, forKey: kObjects)
		encoder.encode(customLabels, forKey: kLabels)
		encoder.encode(photoIndex, forKey: kPhotoIndex)
		encoder.finishEncoding()
		
		// add our new annotations file
		let annotationsWrapper = FileWrapper(regularFileWithContents: encoder.encodedData)
		annotationsWrapper.setFilename("annotations")
		
		fileWrapper.addFileWrapper(annotationsWrapper, canOverwrite: true)
		
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
				self.delegate.projectDidLoad(document: self)
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
		CreateMLExporter(document: self)
			.export(url: url, completion: completion)
	}
	
	func exportTuriCreate(url: URL, completion: ((Bool) -> Void)? = nil) {
		TuriExporter(document: self)
			.export(url: url, completion: completion)
	}
	
	// MARK: Package Actions
	
	/// Converts an image to PNG
	/// - Parameter original: Original file wrapper
	/// - Parameter image: Original image
	
	private func convertToPng(original: FileWrapper, image: NSImage) {
		
		guard let pngData = image.tiffRepresentation?.bitmap?.png else {
			return
		}
		
		// update our wrapper
		photosWrapper.removeFileWrapper(original)
		
		let pngPhotoWrapper = FileWrapper(regularFileWithContents: pngData)
		pngPhotoWrapper.setFilename(original.filename!)
		
		photosWrapper.addFileWrapper(pngPhotoWrapper)
	}
	
	private func createThumbnail(from data: Data, withFilename filename: String, withSize size: NSSize) -> NSImage? {
	
		// generate its thumbnail using Image I/O
		let thumbnail = thumbnailify(photoData: data, size: size)
		
		let thumbnailCacheWrapper = FileWrapper(regularFileWithContents: thumbnail!.tiffRepresentation!.bitmap!.png!)
		
		thumbnailCacheWrapper.setFilename(filename)
		self.thumbnailWrapper.addFileWrapper(thumbnailCacheWrapper, canOverwrite: true)
		
		return thumbnail
	}
	
	func addPhotos(from urls: [URL], at start: Int = -1, available: ((Int, Bool) -> ())? = nil, thumbnailAvailable: (() -> ())? = nil) {
		
		let index = photoIndex
		var importCount = 0
	
		let base = start == -1 ? 0 : start
		
		let task = DispatchWorkItem {
			for url in urls {
				
				guard let data = try? Data(contentsOf: url),
					let image = NSImage(data: data)
					else {
					continue
				}
				
				// unsupported images will be converted to PNG
				let isAnAcceptedFileType = CreateMLImageTypes.contains(url.pathExtension.lowercased())
				let fileExtension = isAnAcceptedFileType ? url.pathExtension : "png"
				
				let filename = "Photo \(index + importCount).\(fileExtension)"
				
				// copy the image data to our "Photos" directory
				
				let photoWrapper = FileWrapper(regularFileWithContents: data)
				photoWrapper.setFilename(filename)
				self.photosWrapper.addFileWrapper(photoWrapper, canOverwrite: true)
				
				// add our photo annotation object to the list
				let object = PhotoAnnotation(filename: filename)
				self.objects.insert(object, at: base)
				
				// a new object is available!
				DispatchQueue.main.async {
					available?(base, true)
				}
				
				// convert unsupported images to PNG (so we can quickly export them to Create ML later)
				if !isAnAcceptedFileType {
					self.convertToPng(original: photoWrapper, image: image)
				}
				
				// generate its thumbnail
				let thumbnail = self.createThumbnail(from: data, withFilename: filename, withSize: image.size)
				
				object.thumbnail = thumbnail
				
				DispatchQueue.main.async {
					thumbnailAvailable?()
				}
				
				self.photoIndex += 1
				importCount += 1
			}
		}
		
		// perform our import actions in a different thread (to keep our UI responsive)
		DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now(), execute: task)
		self.updateChangeCount(.changeDone)
		
		// register our undo import action
		undoManager?.registerUndo(withTarget: self) {
			
			// stop importing photos (if it's still running)
			task.cancel()
			
			// exterminate... exterminate...
			for _ in 0 ..< importCount {
				
				guard base < $0.objects.count,
					let filename = $0.objects[base].photoFilename,
					let photoWrapper = $0.photosWrapper.fileWrappers?[filename] else {
					continue
				}
				
				$0.objects.remove(at: base)
				$0.photosWrapper.removeFileWrapper(photoWrapper)
			
				if let thumbnailWrapper = $0.thumbnailWrapper.fileWrappers?[filename] {
					$0.thumbnailWrapper.removeFileWrapper(thumbnailWrapper)
				}
				
				DispatchQueue.main.async {
					available?(base, false)
				}
			}
			
			// revert our photo index back to its previous value
			$0.photoIndex = index
			$0.updateChangeCount(.changeUndone)
			
			// redo import action
			$0.undoManager?.registerUndo(withTarget: $0) {
				$0.addPhotos(from: urls, at: start, available: available, thumbnailAvailable: thumbnailAvailable)
			}
		}
		
		undoManager?.setActionName("uDPIMP".l)
	}
	
	func addPhotos(_ images: [NSImage], at start: Int = -1, available: ((Int, Bool) -> ())? = nil, thumbnailAvailable: (() -> ())? = nil) {
		
		let index = photoIndex
		var importCount = 0

		let base = start == -1 ? 0 : start
		
		let task = DispatchWorkItem {
			
			for image in images {
				let filename = "Photo \(index + importCount).png"
				
				guard let data = image.tiffRepresentation,
					let image = NSImage(data: data) else {
					continue
				}
				
				// create a temporary file wrapper
				let fileWrapper = FileWrapper(regularFileWithContents: data)
				
				fileWrapper.setFilename(filename)
				
				let object = PhotoAnnotation(filename: filename)
				self.objects.insert(object, at: base)
				
				// Get its real size
				let imageRep = image.representations.first!
				object.rw = imageRep.pixelsWide
				object.rh = imageRep.pixelsHigh
				
				// Get its scaled size
				object.w = Int(image.size.width)
				object.h = Int(image.size.height)
				
				DispatchQueue.main.async {
					available?(base, true)
				}
				
				// generate its thumbnail
				let thumbnail = self.createThumbnail(from: data, withFilename: filename, withSize: image.size)
				
				object.thumbnail = thumbnail
				
				DispatchQueue.main.async {
					thumbnailAvailable?()
				}
				
				// convert it into PNG
				self.convertToPng(original: fileWrapper, image: image)
				
				importCount += 1
				self.photoIndex += 1
			}
		}
		
		DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now(), execute: task)
		
		// register its undo action
		undoManager?.registerUndo(withTarget: self) {
			
			task.cancel()
			
			//
			for _ in 0 ..< importCount {
				
				guard base < $0.objects.count,
					let filename = $0.objects[base].photoFilename,
					let photoWrapper = $0.photosWrapper.fileWrappers?[filename] else {
					continue
				}
				
				$0.objects.remove(at: base)
				$0.photosWrapper.removeFileWrapper(photoWrapper)
			
				if let thumbnailWrapper = $0.thumbnailWrapper.fileWrappers?[filename] {
					$0.thumbnailWrapper.removeFileWrapper(thumbnailWrapper)
				}
				
				DispatchQueue.main.async {
					available?(base, false)
				}
			}
			
			//
			self.photoIndex = index
			$0.updateChangeCount(.changeUndone)
			
			//
			$0.undoManager?.registerUndo(withTarget: $0) {
				$0.addPhotos(images, at: start, available: available, thumbnailAvailable: thumbnailAvailable)
			}
		}
	}
	
	func removePhoto(at row: Int, completion: ((Bool) -> ())? = nil) {
		guard row >= 0 && row < objects.count else {
			return
		}
		
		let object = objects[row]
		
		guard let filename = object.photoFilename else {
			return
		}
		
		// remove it from our objects list
		objects.remove(at: row)

		guard let photo = photosWrapper.fileWrappers?[filename]?.regularFileContents,
			let thumbnail = thumbnailWrapper.fileWrappers?[filename]?.regularFileContents else {
				return
		}
		
		let photoWrapper = FileWrapper(regularFileWithContents: photo)
		let ThumbnailWrapper = FileWrapper(regularFileWithContents: thumbnail)
		
		photoWrapper.setFilename(filename)
		ThumbnailWrapper.setFilename(filename)

		// remove its photo and thumbnail files from our package
		photosWrapper.removeFileWrapper(withFilename: filename)
		thumbnailWrapper.removeFileWrapper(withFilename: filename)
		
		// register our undo action
		undoManager?.registerUndo(withTarget: self) {
			// re-insert the deleted object back to our list
			$0.objects.insert(object, at: row)
			
			//
			
			$0.photosWrapper.addFileWrapper(photoWrapper)
			$0.thumbnailWrapper.addFileWrapper(ThumbnailWrapper)
			
			//
			
			$0.updateChangeCount(.changeUndone)
			completion?(false)
			
			$0.undoManager?.registerUndo(withTarget: $0) {
				$0.removePhoto(at: row, completion: completion)
			}
		}
		
		undoManager?.setActionName("uDPDEL".l)
		
		//
		self.updateChangeCount(.changeDone)
		completion?(true)
	}
	
	func getPhoto(for object: PhotoAnnotation?, isThumbnail: Bool = false) -> NSImage? {
		
		guard let object = object,
			let wrapper = isThumbnail ? thumbnailWrapper : photosWrapper
			else {
			return nil
		}
		
		let filename = object.photoFilename!
		var photoWrapper: FileWrapper!
		
		// Find a matching file wrapper
		for file in wrapper.fileWrappers!.values {
			if file.isRegularFile && file.preferredFilename == filename {
				photoWrapper = file
				break
			}
		}
		
		guard photoWrapper != nil,
			let data = photoWrapper.regularFileContents,
			let photo = NSImage(data: data)
			else {
			return nil
		}
		
		// Update its real size property (if it's not set)
		if object.rw == -1 || object.rh == -1 {
			let imageRep = photo.representations.first!
			object.rw = imageRep.pixelsWide
			object.rh = imageRep.pixelsHigh
		}
		
		// Update its scaled size
		if object.w == -1 || object.h == -1 {
			object.w = Int(photo.size.width)
			object.h = Int(photo.size.height)
		}
			
		return photo
	}
	
	// MARK: Background Actions
	
	func indexLabels() {
		let objects = self.objects
		let udl = customLabels
		
		// cancel our previously-uncompleted indexing task
		indexingTask?.cancel()
		
		let task = DispatchWorkItem {
			var labels: [String] = []
			
			for object in objects {
				for annotation in object.annotations {
					let label = annotation.label
					
					// exclude unlabeled items and user-defined labels
					guard label != "ALD".l && !label.isEmpty && !udl.contains(label) else {
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
				
				// this task has finished successfully!
				self.indexingTask = nil
			}
		}
		
		// run our indexing task in the background
		indexingTask = task
		
		DispatchQueue.global(qos: .background).asyncAfter(deadline: .now(), execute: task)
	}
}
