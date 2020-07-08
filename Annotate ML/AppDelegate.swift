//
//  AppDelegate.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 21/10/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa
import Vision

fileprivate let kHasShownOnboardingScreen = "hasShownOnboardingScreenToUser"

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	
	static let appearanceChanged = NSNotification.Name(rawValue: "appAppearanceChanged")
	
	private var appearanceObserver: NSKeyValueObservation!
	var model: VNCoreMLModel?
		 
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		
		// Send a notification whenever the user changes their system appearance
		// https://indiestack.com/2018/10/supporting-dark-mode-responding-to-change/
		
		if #available(macOS 10.14, *) {
			appearanceObserver = NSApp.observe(\.effectiveAppearance) { _, _ in
				NC.post(AppDelegate.appearanceChanged, object: nil)
			}
		}
		
		// show the first-time launch screen
		if !UserDefaults.standard.bool(forKey: kHasShownOnboardingScreen) {
			let onboardingWC = NSStoryboard.main?.instantiateController(withIdentifier: "Intro") as! NSWindowController
			
			// show our onboarding screen at the centre of the screen
			onboardingWC.showWindow(self)
			onboardingWC.window!.center()
			
			// don't show this the next time it launches
			UserDefaults.standard.set(true, forKey: kHasShownOnboardingScreen)
		}
		
		// load our suggestions classification model
		guard #available(macOS 10.14, *) else {
			return
		}
		
		do {
			model = try VNCoreMLModel(for: Resnet50Int8LUT().model)
		} catch {
			print("There was a problem loading the classification model!")
		}
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}
}

