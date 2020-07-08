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

// MARK: Aliases

typealias NC = NotificationCenter
typealias NCName = NSNotification.Name

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
	
	func addFileWrapper(_ fileWrapper: FileWrapper, canOverwrite: Bool) {
		
		if canOverwrite, let filename = fileWrapper.filename {
			// check if the file already exists
			if let existingFileWrapper = fileWrappers?[filename] {
				// if it does, then remove it
				self.removeFileWrapper(existingFileWrapper)
			}
		}
		
		self.addFileWrapper(fileWrapper)
	}
}

// MARK: Thumbnailing

/// Creates a thumbnail of a photo
/// - Parameter photo: the photo to use
func thumbnailify(photoData data: Data, size: NSSize) -> NSImage? {
	
	let options: [CFString: Any] = [
		kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
		kCGImageSourceCreateThumbnailWithTransform: true,
		kCGImageSourceShouldCacheImmediately: true,
		kCGImageSourceThumbnailMaxPixelSize: thumbnailSize
	]
	
	// create image thumbnail using Image I/O
	guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
		let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
		else {
			return nil
	}
	
	// thumbnail size
	let ratio = thumbnailSize * size.width
	let width = size.width * ratio
	let height = size.height * ratio
	
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

// MARK: Notification Centre

extension NotificationCenter {
	
	static func post(_ name: NCName, info userInfo: [AnyHashable: Any]? = nil, object: Any? = nil, onMain main: Bool = false) {
		
		let centre = NotificationCenter.default
		
		if main {
			DispatchQueue.main.async {
				centre.post(name: name, object: object, userInfo: userInfo)
			}
		}
		
		else {
			centre.post(name: name, object: object, userInfo: userInfo)
		}
	}
	
	static func post(_ name: NCName, value object: Any? = nil, info userInfo: [AnyHashable: Any]? = nil, onMain main: Bool = false) {
	
		NotificationCenter.post(name, info: userInfo, object: object, onMain: main)
	}
	
	static func observe(_ name: NCName, using selector: Selector, on observer: Any, watch object: Any? = nil) {
		
		let centre = NotificationCenter.default
		centre.addObserver(observer, selector: selector, name: name, object: object)
	}
	
	static func stopObserving(_ name: NCName, on observer: Any, specifically object: Any? = nil) {
		
		let centre = NotificationCenter.default
		centre.removeObserver(observer, name: name, object: object)
	}
}

extension NSNotification.Name {
	
	static func name(_ string: String) -> NSNotification.Name {
		return NSNotification.Name(rawValue: string)
	}
}

// MARK: Accessibility

#if os(macOS)

func alert(title: String, message: String, style: NSAlert.Style = .informational) {
	
	let alert = NSAlert()
	
	alert.messageText = title
	alert.informativeText = message
	alert.alertStyle = style
	alert.addButton(withTitle: "ok".l)
	
	alert.runModal()
}

extension NSAccessibility {
	
	static var reducedMotionEnabled: Bool {
		get {
			if #available(macOS 10.12, *) {
				return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
			}
			
			else {
				return false
			}
		}
	}

	static var highContrastEnabled: Bool {
		get {
			NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
		}
	}
}

#endif
