//
//  CommonExtensions.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 21/10/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa

extension NSImage {
	
	// original function from:
	// https://blog.alexseifert.com/2016/06/18/resize-an-nsimage-proportionately-in-swift/
	// (Updated to Swift 5!)
	
	func resize(_ maxSize: NSSize) -> NSImage {
		var ratio: Float = 0.0
		
		let imageWidth = Float(size.width)
		let imageHeight = Float(size.height)
		let maxWidth = Float(maxSize.width)
		let maxHeight = Float(maxSize.height)

		// Get ratio (landscape or portrait)
		if (imageWidth > imageHeight) {
			// Landscape
			ratio = maxWidth / imageWidth
		}
		else {
			// Portrait
			ratio = maxHeight / imageHeight
		}

		// Calculate new size based on the ratio
		let newWidth = imageWidth * ratio
		let newHeight = imageHeight * ratio

		// Create a new NSSize object with the newly calculated size
		let newSize: NSSize = NSSize(width: Int(newWidth), height: Int(newHeight))

		// Cast the NSImage to a CGImage
		var imageRect: CGRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
		let imageRef = cgImage(forProposedRect: &imageRect, context: nil, hints: nil)

		// Create NSImage from the CGImage using the new size
		let imageWithNewSize = NSImage(cgImage: imageRef!, size: newSize)

		// Return the new image
		return imageWithNewSize
	}

}

extension NSColor {
	var bestForeground: NSColor {
		get {
			let colour = self.usingColorSpace(.sRGB)
			
			let red = colour!.redComponent
			let green = colour!.greenComponent * 2
			let blue = colour!.blueComponent
			
			let score = red + green + blue
			return score > 2.28 ? .black : .white
		}
	}
}

extension String {
	var l: String {
		get {
			return NSLocalizedString(self, comment: "")
		}
	}
}
