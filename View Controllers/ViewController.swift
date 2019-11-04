//
//  ViewController.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 21/10/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa

fileprivate let cellIdentifier = NSUserInterfaceItemIdentifier("cell")

class ViewController: NSViewController {
	
	@IBOutlet weak var photosTableView: NSTableView!
	@IBOutlet weak var annotationsView: AnnotationsView!
	
	@IBOutlet weak var scrollView: NSScrollView!
	
	@IBOutlet weak var splitView: NSSplitView!
	
	private weak var lastPopover: NSPopover?
	private weak var document: Document?
	
	var thumbnails: [NSImage] = []
	
	var activeObject: PhotoAnnotation? {
		get {
			let row = photosTableView.selectedRow
			
			guard row >= 0 && row < document!.objects.count else {
				return nil
			}
			
			return document!.objects[row]
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		annotationsView.delegate = self
		
		photosTableView.dataSource = self
		photosTableView.delegate = self
		
		scrollView.wantsLayer = true
		
		// allow the user to drop photos or links to theirhotos table view
		photosTableView.registerForDraggedTypes([.fileURL, .png, .tiff, .URL])
		
		photosTableView.setDraggingSourceOperationMask(.move, forLocal: true)
		photosTableView.setDraggingSourceOperationMask(.copy, forLocal: false)
	}

	override var representedObject: Any? {
		didSet {
			if let document = representedObject as? Document {
				self.document = document
				document.delegate = self
				
				if document.isLoading {
					loadingStarted()
				}
			}
		}
	}
}

extension ViewController: NSTableViewDataSource, NSTableViewDelegate {
	
	// MARK: Table View Delegate
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return document?.objects.count ?? 0
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		
		let cell = photosTableView.makeView(withIdentifier: cellIdentifier, owner: nil) as! ThumbnailCellView
		
		// thumbnail "processing" indicator
		if row >= 0 && row < thumbnails.count {
			cell.processingIndicator.stopAnimation(self)
			cell.photo.image = thumbnails[row]
		} else {
			cell.processingIndicator.startAnimation(self)
			cell.photo.image = nil
		}
		
		return cell
	}
	
	func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
		
		guard edge == .trailing else {
			return []
		}
		
		let delete = NSTableViewRowAction(style: .destructive, title: "Del".l) { _, row in
			
			self.deletePhoto(at: row)
		}
		
		return [delete]
	}
	
	func tableViewSelectionDidChange(_ notification: Notification) {
		guard let object = activeObject else {
			return
		}
		
		annotationsView.object = object
	}
	
	// MARK: Drag and Drop
	
	func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
		
		// re-ordering operation
		if let source = info.draggingSource as? NSTableView, source == photosTableView {
			return .move
		}
		
		// add photos operation
		return .copy
	}
	
	func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
		
		guard dropOperation == .above else {
			return false
		}
		
		let pb = info.draggingPasteboard
		
		// actual photo data
		if let images = pb.readObjects(forClasses: [NSImage.self], options: [:]) as? [NSImage] {
			
			self.addImages(images: images, at: row)
		}
		
		// URLS
		if let urls = pb.readObjects(forClasses: [NSURL.self], options: [:]) as? [URL] {
			
			DispatchQueue.global(qos: .userInitiated).async {
				var images: [NSImage] = []
				
				for url in urls {
					guard let data = try? Data(contentsOf: url),
						let image = NSImage(data: data)
						else {
							continue
					}
					
					images.append(image)
				}
				
				DispatchQueue.main.sync {
					self.addImages(images: images, at: row)
				}
			}
		}
		
		return true
	}}

extension ViewController: DocumentDelegate {
	
	// MARK: Document Delegate
	
	func loadingStarted() {
		splitView.isHidden = true
	}
	
	func projectDidLoad() {
		
		// show the main UI once our project loads completely
		splitView.isHidden = false
		photosTableView.reloadData()
		
		document!.indexLabels()
		
		// start getting photo thumbnails
		getThumbnails()
	}
	
	func projectChanged() {
		annotationsView.object = nil
	}
}

extension ViewController: AnnotationsViewDelegate {
	
	// MARK: Annotations Delegate
	
	func annotationCreated(annotation: Annotation) {
		document!.updateChangeCount(.changeDone)
	}
	
	func annotationSelected(annotation: Annotation, at: NSPoint) {
		// print("Annotation \(annotation.label) clicked at \(at)")
		
		// pop open our annotation editor
		let editorVC = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Annotation Popover")) as! AnnotationLabelViewController
		
		editorVC.object = annotation
		editorVC.document = document
		editorVC.delegate = self
		
		let popover = NSPopover()
		popover.contentViewController = editorVC
		popover.behavior = .transient
		
		lastPopover = popover
		
		editorVC.popover = popover
		popover.show(relativeTo: annotation.cgRect, of: annotationsView, preferredEdge: .maxY)
	}
	
	func annotationPhotoRequested(for object: PhotoAnnotation) -> NSImage? {
		return document!.getPhoto(for: object)
	}
}

extension ViewController: AnnotationLabelViewControllerDelegate {
	
	// MARK: Annotation Label Del.
	
	func labelChanged() {
		annotationsView.setNeedsDisplay()
		document!.indexLabels()
	}
	
	func delete(annotation: Annotation) {
		
		for (i, object) in activeObject!.annotations.enumerated() {
			if object == annotation {
				activeObject!.annotations.remove(at: i)
				break
			}
		}
		
		document!.indexLabels()
		
		// update our annotations view
		document!.updateChangeCount(.changeDone)
		annotationsView.setNeedsDisplay()
	}
}

extension ViewController: NSWindowDelegate {
	func windowDidResize(_ notification: Notification) {
		// let window = notification.object as! NSWindow
	}
}

extension ViewController {
	
	// MARK: Actions
	
	func addImages(images: [NSImage], at start: Int = -1) {
				
		document!.addPhotos(images, at: start) { row in
			self.photosTableView.insertRows(at: [row], withAnimation: .slideDown)
			self.getThumbnails()
			
			self.document!.updateChangeCount(.changeDone)
		}
	}
	
	func addImages(images: [URL], at start: Int = -1) {
				
		document!.addPhotos(from: images, at: start) { row in
			self.photosTableView.insertRows(at: [row], withAnimation: .slideDown)
			self.getThumbnails()
			
			self.document!.updateChangeCount(.changeDone)
		}
	}
	
	func getThumbnails() {
		guard let document = self.document else {
			return
		}
		
		DispatchQueue.global(qos: .background).async {
			var thumbnails: [NSImage] = []
			
			// get thumbnail images from our package
			for object in document.objects {
				guard let thumbnail = document.getPhoto(for: object, isThumbnail: true) else {
					continue
				}
				
				thumbnails.append(thumbnail)
			}
			
			DispatchQueue.main.async {
				self.thumbnails = thumbnails
				self.photosTableView.reloadData()
			}
		}
	}
	
	func deletePhoto(at row: Int) {
		let object = self.document!.objects[row]
		
		// reset our detail view if we're deleting the active object
		if self.annotationsView.object == object {
			self.annotationsView.object = nil
		}
		
		self.document!.removePhoto(at: row)
		self.document!.updateChangeCount(.changeDone)
		
		self.photosTableView.removeRows(at: [row], withAnimation: .slideUp)

		// no crashes allowed!
		self.lastPopover?.performClose(self)
	}
	
	func deleteSelectedPhoto() {
		let selected = photosTableView?.selectedRow ?? -1
		
		guard selected >= 0 && selected < document!.objects.count else {
			return
		}
		
		deletePhoto(at: selected)
	}
	
	func previousPhoto() {
		if photosTableView.selectedRow > 0 {
			photosTableView.selectRowIndexes([photosTableView.selectedRow - 1], byExtendingSelection: false)
		}
	}
	
	func nextPhoto() {
		if photosTableView.selectedRow < document!.objects.count {
			photosTableView.selectRowIndexes([photosTableView.selectedRow + 1], byExtendingSelection: false)
		}
	}
	
	func zoom(zoomIn: Bool) {
		scrollView.animator().magnification += (zoomIn ? 0.15 : -0.15)
	}
	
	func zoomReset() {
		scrollView.animator().magnify(toFit: annotationsView.frame)
	}
}

extension ViewController: NSServicesMenuRequestor {
	
	// MARK: Continuity Camera
	
	override func validRequestor(forSendType sendType: NSPasteboard.PasteboardType?, returnType: NSPasteboard.PasteboardType?) -> Any? {
		
		if let pasteboardType = returnType,
			NSImage.imageTypes.contains(pasteboardType.rawValue){
			return self
		}
		
		return super.validRequestor(forSendType: sendType, returnType: returnType)
	}
	
	func readSelection(from pboard: NSPasteboard) -> Bool {
		guard pboard.canReadItem(withDataConformingToTypes: NSImage.imageTypes),
			let image = NSImage(pasteboard: pboard)
			else {
				return false
		}
		
		addImages(images: [image])
		return true
	}
}

extension ViewController {
	
	// MARK: Notification Actions

}
