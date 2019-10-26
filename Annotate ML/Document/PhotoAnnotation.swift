//
//  PhotoAnnotation.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 21/10/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa

fileprivate let kPhoto = "photo"
fileprivate let kAnnotations = "annotations"

class PhotoAnnotation: NSObject, NSSecureCoding {
	
	/// this notification is posted whenever a photo object's thumbnail becomes available
	static let thumbnailAvailable = NSNotification.Name(rawValue: "notificationWasAvailable")
	
	var photo: NSImage!
	var thumbnail: NSImage?
	var annotations: [Annotation] = []
	
	var wasAdded: Bool = false
	
	init(photo: NSImage) {
		super.init()
		
		self.photo = photo
		
		makeThumbnail()
	}
	
	func makeThumbnail() {
		guard let photo = self.photo else {
			return
		}
		
		DispatchQueue.global(qos: .userInitiated).async {
			let thumbnail = photo.resize(NSSize(width: 64, height: 64))
			
			DispatchQueue.main.sync {
				self.thumbnail = thumbnail
				
				// only added objects send this notification
				if self.wasAdded {
					NotificationCenter.default.post(name: PhotoAnnotation.thumbnailAvailable, object: nil)
				}
			}
		}
	}
	
	// MARK: NSCoding
	
	required init?(coder: NSCoder) {
		super.init()
		
		if let photo = coder.decodeObject(of: NSImage.self, forKey: kPhoto) {
			self.photo = photo
			makeThumbnail()
		}
		
		if let annotations = coder.decodeObject(of: [NSArray.self, Annotation.self], forKey: kAnnotations) as? [Annotation] {
			self.annotations = annotations
		}
	}
	
	func encode(with coder: NSCoder) {
		coder.encode(photo, forKey: kPhoto)
		coder.encode(annotations, forKey: kAnnotations)
	}
	
	static var supportsSecureCoding: Bool {
		return true
	}
}
