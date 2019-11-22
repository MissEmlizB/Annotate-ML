//
//  PhotoAnnotation.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 21/10/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa

fileprivate let kFilename = "filename"
fileprivate let kAnnotations = "annotations"

class PhotoAnnotation: NSObject, NSSecureCoding {

	var photoFilename: String!
	var annotations: [Annotation] = []
	var thumbnail: NSImage?
		
	init(filename: String) {
		self.photoFilename = filename
	}
	
	// MARK: NSCoding
	
	required init?(coder: NSCoder) {
		super.init()
		
		if let filename = coder.decodeObject(of: NSString.self, forKey: kFilename) as String? {
			self.photoFilename = filename
		}
		
		if let annotations = coder.decodeObject(of: [NSArray.self, Annotation.self], forKey: kAnnotations) as? [Annotation] {
			self.annotations = annotations
		}
	}
	
	func encode(with coder: NSCoder) {
		coder.encode(photoFilename, forKey: kFilename)
		coder.encode(annotations, forKey: kAnnotations)
	}
	
	static var supportsSecureCoding: Bool {
		return true
	}
}
