//
//  AnnotationLabelViewController.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 23/10/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa
import Vision

protocol AnnotationLabelViewControllerDelegate {
	func labelChanged()
	func delete(annotation: Annotation)
	func renameStarted(oldLabel label: String)
	func renameEnded(annotation: Annotation, newLabel label: String)
}

class AnnotationLabelViewController: NSViewController {
	
	@IBOutlet weak var labelField: NSComboBox!
	@IBOutlet weak var suggestionsLabelView: NSTextField!
	
	// classification progress indicator
	@IBOutlet weak var cpIndicator: NSProgressIndicator!
	var classificationRequest: VNRequest?
	var suggestedLabels: [String] = []
	
	weak var document: Document!
	weak var popover: NSPopover!
	
	var delegate: AnnotationLabelViewControllerDelegate?
	
	weak var object: Annotation? {
		didSet {
			self.originalLabel = object?.label ?? ""
		}
	}
	
	
	var originalLabel: String = ""
	var photo: NSImage!

    override func viewDidLoad() {
        super.viewDidLoad()
		
		labelField?.delegate = self
		labelField?.dataSource = self
		labelField?.stringValue = object?.label ?? "ALD".l
		
		let appDelegate = NSApplication.shared.delegate as! AppDelegate
		
		if let model = appDelegate.model {
			// create our classification request
			classificationRequest = VNCoreMLRequest(model: model) { request, error in
				guard error == nil else {
					return
				}
				
				self.suggest(with: request)
			}
			
			classificationRequest!.preferBackgroundProcessing = true
		}
		
		suggestLabelsForCurrentPhoto()
	}
	
	override func viewWillDisappear() {
		super.viewWillDisappear()
		
		let label = labelField.stringValue
		
		if originalLabel != label {
			delegate?.renameEnded(annotation: object!, newLabel: label)
		}
		
		updateLabel()
	}
}

extension AnnotationLabelViewController: NSComboBoxDelegate, NSComboBoxDataSource {
	
	// MARK: C. Box Delegate + Source
	
	private func updateLabel() {
		object?.label = labelField.stringValue
		delegate?.labelChanged()
	}
	
	func controlTextDidChange(_ obj: Notification) {
		updateLabel()
	}
	
	func controlTextDidBeginEditing(_ obj: Notification) {
		delegate?.renameStarted(oldLabel: labelField.stringValue)
	}
	
	func controlTextDidEndEditing(_ obj: Notification) {
		popover.performClose(self)
	}
	
	func comboBoxSelectionIsChanging(_ notification: Notification) {
		updateLabel()
	}
	
	func comboBoxSelectionDidChange(_ notification: Notification) {
		updateLabel()
	}
	
	func comboBoxWillDismiss(_ notification: Notification) {
		popover.performClose(self)
	}
	
	func numberOfItems(in comboBox: NSComboBox) -> Int {
		return labels.count
	}
	
	func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
		
		guard index >= 0 && index < labels.count else {
			return nil
		}
		
		return labels[index]
	}
}

extension AnnotationLabelViewController {
	
	// MARK: Actions
	
	@IBAction func delete(sender: AnyObject) {
		delegate?.delete(annotation: object!)
		popover.performClose(self)
	}
}

extension AnnotationLabelViewController {
	
	var labels: [String] {
		get {
			return (document?.allLabels ?? []) + suggestedLabels
		}
	}
	
	// MARK: Suggestions
	
	func suggestLabelsForCurrentPhoto() {
		
		// check if our classification model is available
		
		guard classificationRequest != nil else {
			suggestionsLabelView.stringValue = "SUGUN".l
			return
		}
		
		// check if label suggestions is enabled
		
		let suggestionsEnabled = UserDefaults.standard.bool(forKey: kPreferencesSuggestionsEnabled)
		
		guard suggestionsEnabled else {
			suggestionsLabelView.stringValue = "SUGDIS".l
			return
		}
		
		guard let object = self.object,
			let request = self.classificationRequest,
			let photoData = self.photo.tiffRepresentation?.bitmap?.png
			else {
			return
		}
		
		suggestionsLabelView.isHidden = true
		cpIndicator.startAnimation(self)
		cpIndicator.isHidden = false
		
		DispatchQueue.global(qos: .userInteractive).async {
			
			// get a CGImage representation of the active photo
			let dataProvider = CGDataProvider(data: photoData as CFData)!
			let photo = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
			let cropped = photo.cropping(to: object.cgRect)!
			
			// start classification
			let handler = VNImageRequestHandler(cgImage: cropped, orientation: .up, options: [:])
			try? handler.perform([request])
		}
	}

	func suggest(with request: VNRequest) {
		
		guard let observations = request.results as? [VNClassificationObservation] else {
			return
		}
		
		// update suggestions with our classification result
		
		var suggestions: [String] = []
		
		for (i, observation) in observations.enumerated() {
			guard i < 10 else {
				break
			}
			
			let identifier = observation.identifier
			
			if !identifier.isEmpty {
				suggestions.append(identifier)
			}
		}
		
		DispatchQueue.main.async {
			self.suggestionsLabelView.isHidden = false
			self.cpIndicator.stopAnimation(self)
			self.cpIndicator.isHidden = true
			
			self.suggestedLabels = suggestions
			
			if suggestions.count > 0 {
				self.suggestionsLabelView.stringValue = suggestions.joined(separator: ", ")
			} else {
				self.suggestionsLabelView.stringValue = "SUGNL".l
			}
		}
	}
}
