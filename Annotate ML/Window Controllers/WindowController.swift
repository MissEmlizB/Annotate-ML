//
//  WindowController.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 21/10/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa

class WindowController: NSWindowController {
	
	/// this gets posted whenever this window becomes active
	static let documentAvailable = NSNotification.Name(rawValue: "documentIsAvailable")
	
	@IBOutlet weak var saveIndicator: NSProgressIndicator?
	
	weak var viewController: ViewController?
	weak var labelsWC: NSWindowController?
	
	var openImagePanel: NSOpenPanel!
	var exportPanel: NSSavePanel!
	var lastURL: URL?

    override func windowDidLoad() {
        super.windowDidLoad()

		window!.acceptsMouseMovedEvents = true
		
		saveIndicator?.isHidden = true
    
		openImagePanel = NSOpenPanel()
		openImagePanel.allowedFileTypes = NSImage.imageTypes
		openImagePanel.allowsMultipleSelection = true
		openImagePanel.resolvesAliases = true

		exportPanel = NSSavePanel()
		
		viewController = (contentViewController as! ViewController)
		window!.delegate = viewController
		
		NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive(notification:)), name: NSWindow.didBecomeKeyNotification, object: window)
		
		NotificationCenter.default.addObserver(self, selector: #selector(willClose(notification:)), name: NSWindow.willCloseNotification, object: window)
		
		NotificationCenter.default.addObserver(self, selector: #selector(changeTitlebarAppearance(notification:)), name: PreferencesViewController.preferencesChanged, object: nil)
		
		// update our title/tool bar appearance
		
		let usesModernLook = UserDefaults.standard.bool(forKey: kPreferencesCalendarStyleTitlebar)
		
		useModernTitlebarAppearance(usesModernLook)
    }
	
	// MARK: Notification Actions
	@objc func didBecomeActive(notification: NSNotification) {
		// allow our labels view to adapt it's UI for the currently-active document
		NotificationCenter.default.post(name: WindowController.documentAvailable, object: document, userInfo: nil)
	}
	
	@objc func willClose(notification: NSNotification) {

		// unregister our observers
		NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: window)
		
		NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: window)
		
		NotificationCenter.default.removeObserver(self, name: PreferencesViewController.preferencesChanged, object: nil)
	}
	
	@objc func changeTitlebarAppearance(notification: NSNotification) {
		guard let changes = notification.userInfo as? [String: Bool],
			let usesModernLook = changes[kPreferencesCalendarStyleTitlebar] else {
			return
		}
		
		useModernTitlebarAppearance(usesModernLook)
	}
	
	private func useModernTitlebarAppearance(_ modern: Bool) {
		window?.titleVisibility = modern ? .hidden : .visible
		
		if !modern {
			window?.toolbar?.displayMode = .iconAndLabel
		}
	}
	
	// MARK: View Actions
	
	@IBAction func zoomControl(sender: NSSegmentedControl) {
		guard sender.selectedSegment == 1 else {
			zoomOut(sender: sender)
			return
		}
		
		zoomIn(sender: sender)
	}
	
	@IBAction func zoomIn(sender: AnyObject) {
		viewController?.zoom(zoomIn: true)
	}
	
	@IBAction func zoomOut(sender: AnyObject) {
		viewController?.zoom(zoomIn: false)
	}
	
	@IBAction func zoomReset(sender: AnyObject) {
		viewController?.zoomReset()
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
