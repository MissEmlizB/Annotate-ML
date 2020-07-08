//
//  LabelsViewController.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 24/10/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa

fileprivate let mlids = ["mlname", "mlcount"].compactMap { NSUserInterfaceItemIdentifier(rawValue: $0) }
fileprivate let dlids = ["dlname", "dlcount"].compactMap { NSUserInterfaceItemIdentifier(rawValue: $0) }


class LabelsViewController: NSViewController {
	
	@IBOutlet weak var myLabels: NSTableView!
	@IBOutlet weak var detectedLabels: NSTableView!
	weak var activeTableView: NSTableView!
	
	/// this notification is posted when a user renames a label
	static let labelRenamed = NSNotification.Name(rawValue: "labelWasRenamed")
	
	/// this is the value of the cell we're currently editing
	private var oldLabel: String?
	
	weak var document: Document! {
		didSet {
			// Initial tally
			self.tallyLabels()
			
			// Register ourselves to receive indexing notifications
			NC.observe(Document.labelsIndexed, using: #selector(labelsAreAvailable(notification:)), on: self, watch: self.document)
			
			// Update our UI
			self.myLabels.reloadData()
			self.detectedLabels.reloadData()
		}
	}

	private var tally: [String: Int] = [:]
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		myLabels.delegate = self
		myLabels.dataSource = self
		
		detectedLabels.delegate = self
		detectedLabels.dataSource = self
    
		// Whenever the active window changes, adapt our UI to match their document
		NC.observe(WindowController.documentAvailable, using: #selector(activeDocumentChanged(notification:)), on: self)
	}
	
	// MARK: Tally
	
	func tallyLabels() {
		guard let document = self.document else {
			return
		}
		
		DispatchQueue.global(qos: .background).async {
			
			var tally: [String: Int] = [:]
			
			// count how many times each label was used
			for object in document.objects {
				for annotation in object.annotations {
					for label in document.allLabels {
						guard label == annotation.label else {
							continue
						}
						
						if tally[label] != nil {
							tally[label]! += 1
						} else {
							tally[label] = 1
						}
					}
				}
			}
			
			// update our UI
			DispatchQueue.main.async {
				self.tally = tally
				
				let indexesA = IndexSet(self.document!.labels.enumerated().compactMap{ $0.offset })
				let indexesB = IndexSet(self.document!.customLabels.enumerated().compactMap{ $0.offset })
				
				self.myLabels.reloadData(forRowIndexes: indexesB, columnIndexes: [1])
				self.detectedLabels.reloadData(forRowIndexes: indexesA, columnIndexes: [1])				
			}
		}
	}
}

extension LabelsViewController: NSTableViewDelegate, NSTableViewDataSource {
	
	// MARK: Table View
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		
		guard document != nil else {
			return 0
		}
		
		guard tableView == myLabels else {
			return document.labels.count
		}
		
		return document.customLabels.count
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		
		var cell: NSTableCellView!
		let column = tableColumn!.title == "TCL".l ? 0 : 1
		
		switch tableView {
			
		case myLabels:
			cell = (myLabels.makeView(withIdentifier: mlids[column], owner: nil) as! NSTableCellView)
			
			let label = document!.customLabels[row]
			cell.textField!.stringValue = column == 0 ? "\(label)" : "\(tally[label] ?? 0)"
			
			break
			
		case detectedLabels:
			cell = (detectedLabels.makeView(withIdentifier: dlids[column], owner: nil) as! NSTableCellView)
		
			let label = document!.labels[row]
			cell.textField!.stringValue = column == 0 ? "\(label)" : "\(tally[label] ?? 0)"
		
		break
			
		default:
			break
		}
		
		cell.textField!.delegate = self
		return cell
	}
	
	func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge:
		NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
		
		guard tableView == myLabels && edge == .trailing else {
			return []
		}
		
		let deleteAction = NSTableViewRowAction(style: .destructive, title: "Del".l) { _, row in
			
			self.removeCustomLabel(at: row)
		}
		
		return [deleteAction]
	}
	
}

extension LabelsViewController: NSTextFieldDelegate {
	
	// MARK: Table View Editing

	func controlTextDidBeginEditing(_ obj: Notification) {
		let textField = obj.object as! NSTextField
		oldLabel = textField.stringValue
	}
	
	func controlTextDidEndEditing(_ obj: Notification) {
		
		guard let old = oldLabel else {
			return
		}
		
		let textField = obj.object as! NSTextField
		let new = textField.stringValue
		
		// make sure that we can't rename it to an already-existing label
		guard !document!.allLabels.contains(new) else {
			
			let alert = NSAlert()
			alert.alertStyle = .critical
			
			alert.messageText = "RFT".l
			alert.informativeText = "RFIT".l
			
			alert.addButton(withTitle: "Ok".l)
			alert.runModal()
			
			// restore it to its old label
			textField.stringValue = old
			
			return
		}
		
		self.massRename(old: old, new: new)
	}
}

extension LabelsViewController {
	
	// MARK: Notification Centre
	
	@objc func labelsAreAvailable(notification: NSNotification) {
		detectedLabels.reloadData()
		tallyLabels()		
	}

	@objc func activeDocumentChanged(notification: NSNotification) {
		
		// we don't really need to do anything if we're switching to the same document
		guard let document = notification.object as? Document,
			document != self.document
			else {
			return
		}
		
		// if we have any previous document references, remove this as its observer
		if self.document != nil {
			NC.stopObserving(Document.labelsIndexed, on: self, specifically: self.document)
		}
		
		self.document = document
	}
	
	// MARK: Actions
	@IBAction func addCustomLabel(sender: AnyObject) {
		addCustomLabel()
	}
	
	@IBAction func removeCustomLabel(sender: AnyObject) {
		let selectedRow = myLabels.selectedRow
		
		guard selectedRow >= 0 && selectedRow < document!.customLabels.count else {
			return
		}
		
		removeCustomLabel(at: selectedRow)
	}
	
	@IBAction func refreshLabels(sender: AnyObject) {
		document!.indexLabels()
	}
	
	// MARK: Touchbar Actions
	@IBAction func massRenameLabels(sender: AnyObject) {
		let selectedTable = myLabels.isHighlighted ? myLabels : detectedLabels
		
		guard let selection = selectedTable?.selectedRow else {
			return
		}
		
		selectedTable?.editColumn(0, row: selection, with: nil, select: true)
	}
}

extension LabelsViewController {
	
	// MARK: Undo Action
	
	private func massRename(old: String, new: String, registersUndo: Bool = true) {
		
		// this is obviously not a rename
		guard old != new else {
			return
		}
		
		// replace EVERY annotation that has the old label with our new one
		for object in document!.objects {
			for annotation in object.annotations {
				if annotation.label == old {
					annotation.label = new
				}
			}
		}
		
		// and of course, finalise it by renaming our old label in the document
		for i in 0 ..< document!.labels.count {
			if document!.labels[i] == old {
				document!.labels[i] = new
			}
		}
		
		for i in 0 ..< document!.customLabels.count {
			if document!.customLabels[i] == old {
				document!.customLabels[i] = new
			}
		}
		
		// Update our UI
		document!.updateChangeCount(.changeDone)
		NC.post(LabelsViewController.labelRenamed, object: nil)
		
		// update our tables
		detectedLabels?.reloadData()
		myLabels?.reloadData()
		
		// update our labels
		refreshLabels(sender: self)
		
		// register our undo action
		guard registersUndo else {
			return
		}
		
		undoManager?.registerUndo(withTarget: self) {
			$0.undoManager?.registerUndo(withTarget: $0) {
				$0.massRename(old: old, new: new)
			}
			
			$0.massRename(old: new, new: old, registersUndo: false)
		}
		
		undoManager?.setActionName("uLVMREN".l)
	}
	
	private func addCustomLabel() {
		var name = "CLD".l
		let count = document!.customLabels.count
		
		if count > 0 {
			name += " \(count + 1)"
		}
		
		document!.customLabels.append(name)
		document!.updateChangeCount(.changeDone)
		
		myLabels.insertRows(at: [count], withAnimation: .slideDown)
		
		//
		undoManager?.registerUndo(withTarget: self) {
			$0.undoManager?.registerUndo(withTarget: self) {
				$0.addCustomLabel()
			}
			
			$0.document!.customLabels.removeLast()
			$0.document!.updateChangeCount(.changeUndone)
			
			$0.myLabels.removeRows(at: [count], withAnimation: .slideUp)
		}
		
		undoManager?.setActionName("uLEACL".l)
	}
	
	private func removeCustomLabel(at row: Int) {
		
		let object = self.document!.customLabels[row]
		
		self.document!.customLabels.remove(at: row)
		myLabels.removeRows(at: [row], withAnimation: .slideUp)
		
		self.document!.updateChangeCount(.changeDone)
		
		//
		undoManager?.registerUndo(withTarget: self) {
			$0.undoManager?.registerUndo(withTarget: self) {
				$0.removeCustomLabel(at: row)
			}
			
			$0.document!.customLabels.insert(object, at: row)
			$0.document!.updateChangeCount(.changeUndone)
			
			$0.myLabels.insertRows(at: [row], withAnimation: .slideDown)
		}
		
		undoManager?.setActionName("uLERCL".l)
	}
}
