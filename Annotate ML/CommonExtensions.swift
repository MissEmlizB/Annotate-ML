//
//  CommonExtensions.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 21/10/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa
import ImageIO

fileprivate let handleSize: CGFloat = 16
fileprivate let thumbnailSize: CGFloat = 120

// MARK: Colour Foreground
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

// MARK: String Localisation
extension String {
	var l: String {
		get {
			return NSLocalizedString(self, comment: "")
		}
	}
}

// MARK: NSImage -> PNG

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

// MARK: File Wrapper

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

// MARK: Thumbnailing

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

// MARK: NSRect corners

enum Corner {
	case topLeft
	case topRight
	case bottomLeft
	case bottomRight
}

extension NSRect {
	
	/// Gets the NSRect of a handle at a given corner (and scale)
	/// - Parameter corner: Which corner of this box are we interested in?
	/// - Parameter scale: UI scaling (Annotations View)

	func getHandle(at corner: Corner, withScale scale: CGFloat) -> NSRect {
		let rhs = handleSize * scale
		
		switch corner {
		case .topLeft:
			return NSRect(x: origin.x, y: origin.y, width: rhs, height: rhs)
			
		case .topRight:
			return NSRect(x: origin.x + size.width - rhs, y: origin.y, width: rhs, height: rhs)
			
		case .bottomLeft:
			return NSRect(x: origin.x, y: origin.y + size.height - rhs, width: rhs, height: rhs)
			
		case .bottomRight:
			return NSRect(x: origin.x + size.width - rhs, y: origin.y + size.height - rhs, width: rhs, height: rhs)
		}
	}
	
	func getAllHandles(withScale scale: CGFloat) -> [NSRect] {
		return [
			getHandle(at: .topLeft, withScale: scale),
			getHandle(at: .topRight, withScale: scale),
			getHandle(at: .bottomLeft, withScale: scale),
			getHandle(at: .bottomRight, withScale: scale)
		]
	}
}
