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
	
	@IBOutlet weak var annotationsView: AnnotationsView!
	@IBOutlet weak var scrollView: NSScrollView!
	@IBOutlet weak var imageSizeLabel: NSTextField!
	@IBOutlet weak var imageSizeBG: NSVisualEffectView!
	
	weak var photosTableView: NSTableView! {
		
		didSet {

			photosTableView.dataSource = self
			photosTableView.delegate = self
			
			// allow the user to drop photos or links to the photos table view
			photosTableView.registerForDraggedTypes([.fileURL, .png, .tiff, .URL])
			photosTableView.setDraggingSourceOperationMask(.move, forLocal: true)
			photosTableView.setDraggingSourceOperationMask(.copy, forLocal: false)
		}
	}
	
	private weak var lastPopover: NSPopover?
	weak var document: Document?
	
	// labels renaming
	private var previousLabel: String = ""
	
	// photo selection
	private var previousRow = -1
	
	var activeObject: PhotoAnnotation? {
		get {
			let row = photosTableView.selectedRow
			
			guard row >= 0 && row < self.document!.objects.count else {
				return nil
			}
			
			return self.document!.objects[row]
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		annotationsView.delegate = self
		scrollView.wantsLayer = true
		
		// update our annotations view whenever the user renames a label
		annotationsView.setup()
		
		// Image size
		let defaults = UserDefaults.standard
		
		if defaults.object(forKey: kPreferencesShowsImageSize) == nil {
			defaults.setValue(true, forKey: kPreferencesShowsImageSize)
		}
		
		let showsImageSize = defaults.bool(forKey: kPreferencesShowsImageSize) 
		
		imageSizeBG.isHidden = !showsImageSize
		imageSizeBG.layer!.cornerRadius = 12.0
	}

	override func viewWillAppear() {
		
		super.viewWillAppear()
		
		NC.observe(PreferencesViewController.preferencesChanged,
				   using: #selector(preferencesChanged(notification:)),
				   on: self)
	}
	
	override func viewWillDisappear() {
		
		super.viewWillDisappear()

		NC.stopObserving(PreferencesViewController.preferencesChanged, on: self)
	}
}

extension ViewController: NSTableViewDataSource, NSTableViewDelegate {
	
	// MARK: Table View Delegate
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return self.document?.objects.count ?? 0
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		
		var thumbnail: NSImage?
		
		if row >= 0 && row < self.document!.objects.count {
			thumbnail = self.document!.objects[row].thumbnail
		}
		
		let cell = photosTableView.makeView(withIdentifier: cellIdentifier, owner: nil) as! ThumbnailCellView
		
		let isProcessing = thumbnail == nil
		cell.photo.image = thumbnail
		
		isProcessing ? cell.processingIndicator.startAnimation(self) : cell.processingIndicator.stopAnimation(self)
		
		cell.processingIndicator.isHidden = !isProcessing
		
		// set its accessibility label
		cell.setAccessibilityLabel("aSBPH".l)
		
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
	
	func tableView(_ tableView: NSTableView, selectionIndexesForProposedSelection proposedSelectionIndexes: IndexSet) -> IndexSet {
		
		previousRow = tableView.selectedRow
		return proposedSelectionIndexes
	}
	
	func tableViewSelectionDidChange(_ notification: Notification) {
		guard let object = activeObject else {
			return
		}
		
		annotationsView.object = object
		selectPhoto(old: previousRow, new: photosTableView.selectedRow)
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
			self.addImages(images: urls, at: row)
		}
		
		return true
	}}

extension ViewController: DocumentDelegate {
	
	// MARK: Document Delegate
	
	func loadingStarted() {
	}
	
	func projectDidLoad(document: Document) {
		
		// Set our document reference
		if self.document == nil {
			self.document = document
		}
		
		var rows: IndexSet = []
		
		// start processing thumbnails
		for (row, object) in document.objects.enumerated() {
			guard let thumbnail = document.getPhoto(for: object, isThumbnail: true) else {
				continue
			}
			
			object.thumbnail = thumbnail
			rows.insert(row)
		}

		photosTableView.insertRows(at: rows, withAnimation: .slideDown)
		document.indexLabels()
	}
	
	func projectChanged(document: Document) {
		annotationsView.object = nil
	}
}

extension ViewController: AnnotationsViewDelegate {
	
	// MARK: Annotations Delegate
	
	func annotationCreated(annotation: Annotation) {
		self.document!.updateChangeCount(.changeDone)
	}
	
	func annotationSelected(annotation: Annotation, at: NSPoint) {
		
		// pop open our label editor
		let editorVC = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Annotation Popover")) as! AnnotationLabelViewController
		
		editorVC.object = annotation
		editorVC.photo = self.document!.getPhoto(for: activeObject)
		editorVC.document = self.document
		editorVC.delegate = self
		
		let popover = NSPopover()
		popover.contentViewController = editorVC
		popover.behavior = .transient
		
		lastPopover = popover
		
		editorVC.popover = popover
		popover.show(relativeTo: annotation.cgRect, of: annotationsView, preferredEdge: .maxY)
	}
	
	func annotationPhotoRequested(for object: PhotoAnnotation) -> NSImage? {
		return self.document!.getPhoto(for: object)
	}
	
	func annotationActionUndone() {
		self.document!.updateChangeCount(.changeUndone)
	}
	
	func annotationActionRedone() {
		self.document!.updateChangeCount(.changeRedone)
	}
	
	func annotationImageSizeAvailable(size: NSSize) {
		
		// Update our image size label
		guard !imageSizeBG.isHidden else {
			return
		}
		
		let width = Int(size.width)
		let height = Int(size.height)
		
		imageSizeLabel.stringValue = "\(width) x \(height) px"
	}
}

extension ViewController: AnnotationLabelViewControllerDelegate {
	
	// MARK: Annotation Label Del.
	
	func renameStarted(oldLabel label: String) {
		self.previousLabel = label
	}
	
	func renameEnded(annotation: Annotation, newLabel label: String) {
		self.renameAnnotation(annotation: annotation, old: previousLabel, new: label)
	}
	
	func labelChanged() {
		annotationsView.setNeedsDisplay()
		self.document!.indexLabels()
	}
	
	func delete(annotation: Annotation) {
		
		for (i, object) in activeObject!.annotations.enumerated() {
			if object == annotation {
				deleteAnnotation(position: i)
				break
			}
		}
		
		self.document!.indexLabels()
	}
}

extension ViewController {
	
	// MARK: Actions
	
	private func insertOrRemoveRow(at row: Int, inserting: Bool) {
		if inserting {
			photosTableView.insertRows(at: [row], withAnimation: .slideDown)
		} else {
			photosTableView.removeRows(at: [row], withAnimation: .slideUp)
		}
	}
	
	private func reloadTableView() {
		let selection = self.photosTableView.selectedRow
		self.photosTableView.reloadData()
		
		// restore previous selection
		self.photosTableView.selectRowIndexes([selection], byExtendingSelection: false)
	}
	
	@IBAction func deleteSelectedPhoto(sender: AnyObject) {
		let selectedRow = photosTableView.selectedRow
		
		guard selectedRow != -1 else {
			return
		}
		
		self.deletePhoto(at: selectedRow)
	}
	
	func addImages(images: [URL], at start: Int = -1) {
		
		let row = photosTableView.selectedRow
		
		// if our selected row is being affected, deactivate the annotations view
		if row >= start && row < start + images.count {
			photosTableView.deselectAll(self)
			annotationsView.object = nil
		}
		
		self.document!.addPhotos(from: images, at: start,
		
		// this gets triggered whenever a new photo was imported
			
		available: { row, isInserting in
			self.insertOrRemoveRow(at: row, inserting: isInserting)
		},
					
		// this gets triggered whenever a thumbnail gets generated
			
		thumbnailAvailable: {
			self.reloadTableView()
		})
	}
	
	func deletePhoto(at row: Int) {
		
		let object = self.document!.objects[row]
		
		// deactivate annotations view if our currently selected photo is the one being affected by this action
		if row == photosTableView.selectedRow || annotationsView.object == object {
			photosTableView.deselectAll(self)
			annotationsView.object = nil
		}
		
		document!.removePhoto(at: row) { deleting in
			if deleting {
				self.photosTableView.removeRows(at: [row], withAnimation: .slideUp)
			} else {
				self.photosTableView.insertRows(at: [row], withAnimation: .slideDown)
			}
		}

		// close our annotation editor popover (if it's active)
		lastPopover?.performClose(self)
	}
	
	func addImages(images: [NSImage], at start: Int = -1) {
		
		let row = photosTableView.selectedRow
		
		// if our selected row is being affected, deactivate the annotations view
		if row >= start && row < start + images.count {
			photosTableView.deselectAll(self)
			annotationsView.object = nil
		}
				
		self.document!.addPhotos(images, at: start,
							
		available: { row, isInserting in
			self.insertOrRemoveRow(at: row, inserting: isInserting)
		},
		
		thumbnailAvailable: {
			self.reloadTableView()
		})
	}
	
	func deleteSelectedPhoto() {
		let selected = photosTableView?.selectedRow ?? -1
		
		guard selected >= 0 && selected < self.document!.objects.count else {
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
		if photosTableView.selectedRow < self.document!.objects.count {
			photosTableView.selectRowIndexes([photosTableView.selectedRow + 1], byExtendingSelection: false)
		}
	}
	
	func zoom(zoomIn: Bool) {
		scrollView.animator().magnification += (zoomIn ? 0.15 : -0.15)
	}
	
	@IBAction func zoomReset(sender: AnyObject? = nil) {
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
	
	// MARK: Undo Actions
	
	private func selectPhoto(old: Int, new: Int) {
		
		// nothing was selected
		guard new != -1 else {
			photosTableView.deselectAll(self)
			return
		}
		
		// update our selection
		photosTableView.selectRowIndexes([new], byExtendingSelection: false)
		
		// register our undo action
		undoManager?.registerUndo(withTarget: self) {
			$0.undoManager?.registerUndo(withTarget: $0) {
				$0.selectPhoto(old: old, new: new)
			}
			
			$0.selectPhoto(old: new, new: old)
		}
		
		undoManager?.setActionName("uPSW".l)
	}
	
	private func deleteAnnotation(position: Int) {
		annotationsView.deleteAnnotation(position: position)
	}
	
	private func renameAnnotation(annotation: Annotation, old: String, new: String) {
		annotationsView.renameAnnotation(annotation: annotation, old: old, new: new)
	}
}

extension ViewController {

	// MARK: Preferences
	
	@objc private func preferencesChanged(notification: NSNotification?) {
		
		guard let changes = notification?.userInfo as? [String: Bool] else {
			return
		}
		
		if let isSizeShown = changes[kPreferencesShowsImageSize] {
			
			// Animate hiding/showing our image size label
			let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
			animation.isRemovedOnCompletion = true
			animation.fromValue = isSizeShown ? 0.0 : 1.0
			animation.toValue = isSizeShown ? 1.0 : 0.0
			
			CATransaction.begin()
			
			imageSizeBG.layer!.opacity = animation.toValue as! Float
			animation.run(forKey: "opacity", object: imageSizeBG.layer!,
						  arguments: [:])
			
			CATransaction.commit()
		}
	}
}
