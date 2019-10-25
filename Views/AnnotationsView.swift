//
//  AnnotationsView.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 21/10/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa

protocol AnnotationsViewDelegate {
	func annotationCreated(annotation: Annotation)
	func annotationSelected(annotation: Annotation, at: NSPoint)
}

class AnnotationsView: NSImageView {

	var delegate: AnnotationsViewDelegate?
	
	var start: NSPoint!
	var w: Float = 0
	var h: Float = 0
	
	// UI Scaling
	private var annotationLineThickness: CGFloat = 4.0
	private var annotationLabelSize: CGFloat = 12.0
	private var annotationUIScale: CGFloat = 1.0
	private var annotationMinArea: Float = 16

	var controlColour: NSColor {
		get {
			if #available(macOS 10.14, *) {
				return .controlAccentColor
			} else {
				return .systemGreen
			}
		}
	}
	
	// this will make exporting sooo much easier later
	override var isFlipped: Bool {
		return true
	}
	
	// reference to our currently active object's annotations array
	weak var object: PhotoAnnotation? {
		didSet {
			self.image = object?.photo
			
			guard let object = object else {
				return
			}
			
			let size = object.photo.size
			
			// make sure that our image view matches the image's size
			self.frame.size = size

			// also, make sure our UI scales well with the image
			let scale = (size.width + size.height) / 1000

			annotationUIScale = scale
			annotationLineThickness = 4.0 * scale
			annotationLabelSize = 12.0 * scale
			annotationMinArea = Float(16.0 * scale)
			
			// finally, make sure that the entire image is visible when it has been selected
			enclosingScrollView?.magnify(toFit: frame)
			
		}
	}
	
	private func findClickedAnnotation(in event: NSEvent) {
		
		guard let object = object else {
			return
		}
		
		// try to find which annotation the user is trying to select
		let position = convert(event.locationInWindow, from: nil)
		
		for annotation in object.annotations {

			if NSPointInRect(position, annotation.cgRect) {
				delegate?.annotationSelected(annotation: annotation, at: position)
				return
			}
		}
	}
	
	// MARK: Drawing

	private func draw(rect: CGRect) {
		let path = NSBezierPath.init(rect: rect)
		path.lineWidth = annotationLineThickness
		path.lineCapStyle = .round
		path.stroke()
	}
	
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

		guard let object = object else {
			return
		}
		
		// annotation "preview"
		
		NSColor.white.setStroke()
		
		if let start = start {
			let rect = CGRect(x: start.x, y: start.y, width: CGFloat(w), height: CGFloat(h))
			draw(rect: rect)
		}
		
		for annotation in object.annotations {
			
			// annotation outline
			controlColour.setStroke()
			draw(rect: annotation.cgRect)
			
			// label BG
			controlColour.setFill()
			var labelBG = annotation.cgRect
			labelBG.size.height = annotationLabelSize + (12 * annotationUIScale)
			
			let bgPath = NSBezierPath.init(rect: labelBG)
			bgPath.fill()
			
			// label
			let label = NSString(string: annotation.label)
			var point = annotation.cgRect.origin
			
			let padding = 4 * annotationUIScale
			point.x += padding
			point.y += padding
			
			label.draw(at: point, withAttributes: [.font: NSFont.labelFont(ofSize: annotationLabelSize), .foregroundColor: controlColour.bestForeground])
		}
    }
}

extension AnnotationsView {
	
	// MARK: Annotation Creation
	
	private func updateSize(with event: NSEvent) {
		let end = convert(event.locationInWindow, from: nil)
		
		w = Float(end.x - start.x)
		h = Float(end.y - start.y)
	}
	
	override func mouseDown(with event: NSEvent) {
		start = convert(event.locationInWindow, from: nil)
	}
	
	override func mouseDragged(with event: NSEvent) {
		updateSize(with: event)
		self.setNeedsDisplay()
	}
	
	override func mouseUp(with event: NSEvent) {
		
		let a = abs(w * h)
		
		guard object != nil, a > annotationMinArea, let start = start else {
			
			// if the annotation box area is less than 16 assume that the user is selecting
			findClickedAnnotation(in: event)
			
			self.start = nil
			self.setNeedsDisplay()
			
			return
		}
		
		updateSize(with: event)
				
		let rect = CGRect(x: start.x, y: start.y, width: CGFloat(w), height: CGFloat(h)).standardized
		
		// create an empty annotation object
		let annotation = Annotation(rect: rect)
		object?.annotations.append(annotation)
		
		delegate?.annotationCreated(annotation: annotation)
		delegate?.annotationSelected(annotation: annotation, at: annotation.cgRect.origin)
		
		// we don't need these anymore
		self.start = nil
		w = 0
		h = 0
		
		self.setNeedsDisplay()
	}
}
