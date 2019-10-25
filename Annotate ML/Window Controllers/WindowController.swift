//
//  WindowController.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 21/10/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa

class WindowController: NSWindowController {
	
	@IBOutlet weak var saveIndicator: NSProgressIndicator?
	@IBOutlet weak var zoomSlider: NSSlider!
	
	weak var viewController: ViewController?
	weak var labelsWC: NSWindowController?
	
	var openImagePanel: NSOpenPanel!
	var exportPanel: NSSavePanel!
	var savePanel: NSSavePanel!
	
	var lastURL: URL?

    override func windowDidLoad() {
        super.windowDidLoad()
		
		window!.delegate = self
		
		saveIndicator?.isHidden = true
    
		openImagePanel = NSOpenPanel()
		openImagePanel.allowedFileTypes = NSImage.imageTypes
		openImagePanel.allowsMultipleSelection = true
		openImagePanel.resolvesAliases = true
		
		savePanel = NSSavePanel()
		savePanel.allowedFileTypes = ["annotateml"]
		
		exportPanel = NSSavePanel()
		
		viewController = (contentViewController as! ViewController)
		window!.delegate = viewController
		
		// we'll use this to synchronise our touchbar slider to the actual zoom level
		NotificationCenter.default.addObserver(self, selector: #selector(magnificationEnd(notification:)), name: NSScrollView.didEndLiveMagnifyNotification, object: viewController?.scrollView)
		
		updateZoomSlider(viewController?.scrollView.magnification)
    }

	// MARK: View Actions
	
	@IBAction func zoomSliderChanged(sender: NSSlider) {
		viewController?.scrollView?.magnification = CGFloat(sender.floatValue)
	}
	
	@IBAction func zoomControl(sender: NSSegmentedControl) {
		guard sender.selectedSegment == 1 else {
			zoomOut(sender: sender)
			return
		}
		
		zoomIn(sender: sender)
		updateZoomSlider(viewController?.scrollView.magnification)
	}
	
	@IBAction func zoomIn(sender: AnyObject) {
		viewController?.zoom(zoomIn: true)
		updateZoomSlider(viewController?.scrollView.magnification)
	}
	
	@IBAction func zoomOut(sender: AnyObject) {
		viewController?.zoom(zoomIn: false)
		updateZoomSlider(viewController?.scrollView.magnification)
	}
	
	@IBAction func zoomReset(sender: AnyObject) {
		viewController?.zoomReset()
		updateZoomSlider(viewController?.scrollView.magnification)
	}
	
	@IBAction func showLabels(sender: AnyObject) {
		performSegue(withIdentifier: "show labels", sender: sender)
	}
	
	// MARK: Navigation Actions
	
	@IBAction func navigatePhoto(sender: NSSegmentedControl) {
		guard sender.selectedSegment == 1 else {
			previousPhoto(sender: sender)
			return
		}
		
		nextPhoto(sender: sender)
	}
	
	@IBAction func previousPhoto(sender: AnyObject) {
		viewController?.previousPhoto()
	}
	
	@IBAction func nextPhoto(sender: AnyObject) {
		viewController?.nextPhoto()
	}
	
	// MARK: File Actions
	
	@IBAction func openImages(sender: AnyObject) {
		openImagePanel.beginSheetModal(for: window!) { response in
			guard response == .OK else {
				return
			}
			
			let urls = self.openImagePanel.urls
			
			// load the selected photos then pass it to our view controller
			DispatchQueue.global(qos: .userInitiated).async {
				var images: [NSImage] = []
				
				for url in urls {
					guard let photo = NSImage(contentsOf: url) else {
						continue
					}
					
					images.append(photo)
				}
				
				DispatchQueue.main.async {
					self.viewController?.addImages(images: images)
				}
			}
		}
	}
	
	// MARK: Other Actions
	
	func setIndicator(isVisible: Bool) {
		saveIndicator?.isHidden = !isVisible
		isVisible ? saveIndicator?.startAnimation(self) : saveIndicator?.stopAnimation(self)
	}
	
	func showMessage(title: String, message: String, style: NSAlert.Style = .informational) {
		
		// show a basic alert sheet
		let alert = NSAlert()
		
		alert.alertStyle = style
		alert.messageText = title
		alert.informativeText = message
		
		alert.addButton(withTitle: "Ok")
		alert.beginSheetModal(for: window!, completionHandler: nil)
	}
}

extension WindowController {
	
	// MARK: Document Actions
	
	private func save(_ normalSave: Bool) {
		
		guard let document = self.document as? Document else {
			return
		}
		
		setIndicator(isVisible: true)
		
		// since our project files tend to be ginormous
		// we'll save it in the background
		
		let url = lastURL!
		
		DispatchQueue.global(qos: .userInitiated).async {
			let type: NSDocument.SaveOperationType = normalSave ? .saveOperation : .saveAsOperation
			
			document.save(to: url, ofType: "annotateml", for: type) { error in
				
				DispatchQueue.main.async {
					if error != nil {
						self.showMessage(title: "Error", message: "There was a problem saving your project!", style: .critical)
					}
					
					self.setIndicator(isVisible: false)
				}
			}
		}
	}
	
	func performSave(normalSave: Bool) {
		if lastURL == nil || !normalSave {
			savePanel.beginSheetModal(for: window!) { response in
				guard response == .OK else {
					return
				}
				
				self.lastURL = self.savePanel.url
				self.save(normalSave)
			}
		} else {
			self.save(normalSave)
		}
	}
	
	@IBAction func save(sender: AnyObject) {
		
		if lastURL == nil {
			lastURL = document!.fileURL
		}
		
		performSave(normalSave: true)
	}
	
	@IBAction func saveAs(sender: AnyObject) {
		performSave(normalSave: false)
	}
	
	@IBAction func export(sender: AnyObject) {

		exportPanel.beginSheetModal(for: window!) { response in
			guard response == .OK, let url = self.exportPanel.url else {
				return
			}
			
			self.setIndicator(isVisible: true)
			
			let document = self.viewController?.representedObject as! Document
			document.exportCreateML(url: url) { success in
				
				DispatchQueue.main.async {
					
					self.setIndicator(isVisible: false)
					
					// show the appropriate message
					let alert = NSAlert()
					
					alert.alertStyle = success ? .informational : .critical
					
					alert.messageText = success ? "E1".l : "E0".l
					
					alert.informativeText = success
						? "\("EIT1".l) \(url.path)."
						: "EIT0".l
					
					alert.addButton(withTitle: "Ok".l)
					
					alert.runModal()
				}
			}
		}
	}
}

extension WindowController {
	
	// MARK: Notification Actions
	
	private func updateZoomSlider(_ zoom: CGFloat?) {
		
		guard let zoom = zoom else {
			return
		}
		
		zoomSlider.floatValue = Float(zoom)
	}
	
	@objc func magnificationEnd(notification: NSNotification) {
		let object = notification.object as! NSScrollView
		updateZoomSlider(object.magnification)
	}
}

extension WindowController {
	
	// MARK: Segues
	
	override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
		if segue.identifier == "show labels" {
			let wc = segue.destinationController as! NSWindowController
			let vc = wc.contentViewController as! LabelsViewController
			
			vc.document = viewController?.representedObject as? Document
			labelsWC = wc
		}
	}
}

extension WindowController: NSWindowDelegate {
	
	// MARK: Window Delegate
	
	func windowWillClose(_ notification: Notification) {
		labelsWC?.close()
	}
}
