//
//  AnnotationLabelViewController.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 23/10/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa

protocol AnnotationLabelViewControllerDelegate {
	func labelChanged()
	func delete(annotation: Annotation)
}

class AnnotationLabelViewController: NSViewController {
	
	@IBOutlet weak var labelField: NSComboBox!
	weak var document: Document!
	weak var popover: NSPopover!
	
	var delegate: AnnotationLabelViewControllerDelegate?
	
	weak var object: Annotation?

    override func viewDidLoad() {
        super.viewDidLoad()
		
		labelField?.delegate = self
		labelField?.dataSource = self
		labelField?.stringValue = object?.label ?? "ALD".l
	}
}

extension AnnotationLabelViewController: NSComboBoxDelegate, NSComboBoxDataSource {
	
	// MARK: C. Box Delegate + Source
	
	func controlTextDidChange(_ obj: Notification) {
		object?.label = labelField.stringValue
		delegate?.labelChanged()
	}
	
	func controlTextDidEndEditing(_ obj: Notification) {
		popover.performClose(self)
	}
	
	func comboBoxWillDismiss(_ notification: Notification) {
		popover.performClose(self)
	}
	
	func numberOfItems(in comboBox: NSComboBox) -> Int {
		return document.labels.count
	}
	
	func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
		
		guard index >= 0 && index < document.labels.count else {
			return nil
		}
		
		return document.labels[index]
	}
}

extension AnnotationLabelViewController {
	
	// MARK: Actions
	
	@IBAction func delete(sender: AnyObject) {
		delegate?.delete(annotation: object!)
		popover.performClose(self)
	}
}
