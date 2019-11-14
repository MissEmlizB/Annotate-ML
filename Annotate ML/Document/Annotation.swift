//
//  Annotation.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 21/10/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Foundation

fileprivate let kX = "x"
fileprivate let kY = "y"
fileprivate let kW = "width"
fileprivate let kH = "height"
fileprivate let kLabel = "label"

class Annotation: NSObject, NSSecureCoding {
	
	var label: String = "ALD".l
	var x: Float = 0.0
	var y: Float = 0.0
	var w: Float = 0.0
	var h: Float = 0.0
	
	init(x: Float, y: Float, w: Float, h: Float) {
		self.x = x
		self.y = y
		self.w = w
		self.h = h
	}
	
	init(rect: CGRect) {
		self.x = Float(rect.origin.x)
		self.y = Float(rect.origin.y)
		self.w = Float(rect.size.width)
		self.h = Float(rect.size.height)
	}
	
	/// A representation of this object in CGRect/NSRect form
	var cgRect: CGRect {
		get {
			 CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(w), height: CGFloat(h))
		}
		
		set {
			self.x = Float(newValue.origin.x)
			self.y = Float(newValue.origin.y)
			self.w = Float(newValue.width)
			self.h = Float(newValue.height)
		}
	}
	
	/// A representation of this object in JSON form
	var json: [String: Any] {
		get {
			["x": x, "y": y, "width": w, "height": h]
		}
	}
	
	// MARK: NSCoding
	
	required init?(coder: NSCoder) {
		x = coder.decodeFloat(forKey: kX)
		y = coder.decodeFloat(forKey: kY)
		w = coder.decodeFloat(forKey: kW)
		h = coder.decodeFloat(forKey: kH)
		
		if let label = coder.decodeObject(of: NSString.self, forKey: kLabel) as String? {
			self.label = label
		}
	}
	
	func encode(with coder: NSCoder) {
		coder.encode(x, forKey: kX)
		coder.encode(y, forKey: kY)
		coder.encode(w, forKey: kW)
		coder.encode(h, forKey: kH)
		coder.encode(label, forKey: kLabel)
	}
	
	static var supportsSecureCoding: Bool {
		return true
	}
}
