//
//  CommonExtensions.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 21/10/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa
import ImageIO

fileprivate let thumbnailSize: CGFloat = 120

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

// https://stackoverflow.com/questions/29262624/nsimage-to-nsdata-as-png-swift
extension NSBitmapImageRep {
    var png: Data? {
        return representation(using: .png, properties: [:])
    }
}
extension Data {
    var bitmap: NSBitmapImageRep? {
        return NSBitmapImageRep(data: self)
    }
}

extension FileWrapper {
	func setFilename(_ filename: String) {
		self.filename = filename
		self.preferredFilename = filename
	}
	
	func removeFileWrapper(withFilename name: String) {
		guard let wrapper = self.fileWrappers?[name] else {
			return
		}
		
		self.removeFileWrapper(wrapper)
	}
}

/// Creates a thumbnail of a photo
/// - Parameter photo: the photo to use
func thumbnailify(photo: NSImage) -> NSImage? {
	
	let options: [CFString: Any] = [
		kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
		kCGImageSourceCreateThumbnailWithTransform: true,
		kCGImageSourceShouldCacheImmediately: true,
		kCGImageSourceThumbnailMaxPixelSize: thumbnailSize
	]
	
	// create image thumbnail using Image I/O
	guard let imageSource = CGImageSourceCreateWithData(photo.tiffRepresentation! as CFData, nil),
		let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
		else {
			return nil
	}
	
	// thumbnail size
	let ratio = thumbnailSize * photo.size.width
	let width = photo.size.width * ratio
	let height = photo.size.height * ratio
	
	return NSImage(cgImage: image, size: NSSize(width: width, height: height))
}
