//
//  AppDelegate.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 21/10/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa
import Vision

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	
	var model: VNCoreMLModel?
	 
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		
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

