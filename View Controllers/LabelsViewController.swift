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
	
	weak var document: Document! {
		didSet {
			// initial tally
			tallyLabels()
			
			// register ourselves to receive indexing notifications
			NotificationCenter.default.addObserver(self, selector: #selector(labelsAreAvailable(notification:)), name: Document.labelsIndexed, object: nil)
			
			// update our UI
			myLabels.reloadData()
			detectedLabels.reloadData()
		}
	}

	private var tally: [String: Int] = [:]
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		myLabels.delegate = self
		myLabels.dataSource = self
		
		detectedLabels.delegate = self
		detectedLabels.dataSource = self
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
		let column = tableColumn!.title == "Label" ? 0 : 1
		
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
		
		return cell
	}
}

extension LabelsViewController {
	
	// MARK: Notification Centre
	@objc func labelsAreAvailable(notification: NSNotification) {
		detectedLabels.reloadData()
		tallyLabels()
	}
}
