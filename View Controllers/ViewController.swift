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
	@IBOutlet weak var loadIndicator: NSProgressIndicator!
	
	private weak var lastPopover: NSPopover?
	private weak var document: Document?
	
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
		let cell = photosTableView.makeView(withIdentifier: cellIdentifier, owner: nil) as! NSTableCellView
		
		guard row >= 0 && row < document!.objects.count else {
			return nil
		}
		
		cell.imageView?.image = document!.objects[row].thumbnail
		return cell
	}
	
	func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
		
		guard edge == .trailing else {
			return []
		}
		
		let delete = NSTableViewRowAction(style: .destructive, title: "Del".l) { _, row in
			
			let object = self.document!.objects[row]
			
			// reset our detail view if we're deleting the active object
			if self.annotationsView.object == object {
				self.annotationsView.object = nil
			}
			
			self.document!.objects.remove(at: row)
			self.document!.updateChangeCount(.changeDone)
			
			self.photosTableView.removeRows(at: [row], withAnimation: .slideUp)

			// no crashes allowed!
			self.lastPopover?.performClose(self)
		}
		
		return [delete]
		
	}
	
	func tableViewSelectionDidChange(_ notification: Notification) {
		guard let object = activeObject else {
			return
		}
		
		annotationsView.object = object
	}
}

extension ViewController: DocumentDelegate {
	
	// MARK: Document Delegate
	
	func loadingStarted() {
		splitView.isHidden = true
		
		loadIndicator.isHidden = false
		loadIndicator.startAnimation(self)
	}
	
	func projectDidLoad() {
		
		// show the main UI once our project loads completely
		loadIndicator.stopAnimation(self)
		loadIndicator.isHidden = true
		
		splitView.isHidden = false
		photosTableView.reloadData()
		
		document!.indexLabels()
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
		popover.show(relativeTo: annotation.cgRect, of: annotationsView, preferredEdge: .maxX)
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
	
	func addImages(images: [NSImage]) {
		var rows = IndexSet()
		
		// i... photo... get it? Ok, I'm leaving.
		
		for (i, photo) in images.enumerated() {
			let object = PhotoAnnotation(photo: photo)
			document!.objects.append(object)
			
			rows.insert(i)
		}
		
		// update our table view
		photosTableView.insertRows(at: rows, withAnimation: .slideDown)
		document!.updateChangeCount(.changeDone)
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
