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
	
	var photo: NSImage!
	var thumbnail: NSImage!
	var annotations: [Annotation] = []
	
	init(photo: NSImage) {
		super.init()
		
		self.photo = photo
		makeThumbnail()
	}
	
	func makeThumbnail() {
		thumbnail = photo.resize(NSSize(width: 64, height: 64))
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
