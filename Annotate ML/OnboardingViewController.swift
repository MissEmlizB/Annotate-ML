//
//  OnboardingViewController.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 23/11/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa

class OnboardingViewController: NSPageController, NSPageControllerDelegate {
	
	var viewControllers: [String: NSViewController] = [:]
	@IBInspectable var onboardingPageCount: Int = 0
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.delegate = self
		
		guard let storyboard = NSStoryboard.main else {
			return
		}
		
		// load our pages
		for i in 0 ..< onboardingPageCount {
			let identifier = NSStoryboard.SceneIdentifier("Onboarding \(i)")
			
			guard let viewController = storyboard.instantiateController(withIdentifier: identifier) as? NSViewController else {
				continue
			}
			
			viewControllers[identifier] = viewController
			self.arrangedObjects.append(identifier)
		}
	}

	// MARK: Page Controller
	
	func pageController(_ pageController: NSPageController, viewControllerForIdentifier identifier: NSPageController.ObjectIdentifier) -> NSViewController {
		
		return viewControllers[identifier]!
	}
	
	func pageController(_ pageController: NSPageController, identifierFor object: Any) -> NSPageController.ObjectIdentifier {
		
		return String(describing: object)
	}
	
	func pageControllerDidEndLiveTransition(_ pageController: NSPageController) {
		pageController.completeTransition()
	}
}
