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
fileprivate let kRw = "realWidth"
fileprivate let kRh = "realHeight"
fileprivate let kW = "width"
fileprivate let kH = "height"


class PhotoAnnotation: NSObject, NSSecureCoding {

	var photoFilename: String!
	var annotations: [Annotation] = []
	var thumbnail: NSImage?
	var rw: Int = -1
	var rh: Int = -1
	var w: Int = -1
	var h: Int = -1
		
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
		
		self.rw = coder.decodeInteger(forKey: kRw)
		self.rh = coder.decodeInteger(forKey: kRh)
		self.w = coder.decodeInteger(forKey: kW)
		self.h = coder.decodeInteger(forKey: kH)
	}
	
	func encode(with coder: NSCoder) {
		
		coder.encode(photoFilename, forKey: kFilename)
		coder.encode(annotations, forKey: kAnnotations)
		coder.encode(rw, forKey: kRw)
		coder.encode(rh, forKey: kRh)
		coder.encode(w, forKey: kW)
		coder.encode(h, forKey: kH)
	}
	
	static var supportsSecureCoding: Bool {
		return true
	}
}
