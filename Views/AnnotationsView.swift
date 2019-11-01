//
//  AnnotationsView.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 21/10/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa

enum AnnotationsViewState {
	case normal
	case canEnterDragMode
	case dragMode
}

protocol AnnotationsViewDelegate {
	func annotationCreated(annotation: Annotation)
	func annotationSelected(annotation: Annotation, at: NSPoint)
	func annotationPhotoRequested(for object: PhotoAnnotation) -> NSImage?
}

class AnnotationsView: NSImageView {

	var delegate: AnnotationsViewDelegate?
	var state: AnnotationsViewState = .normal
	
	// moving variables
	var trackingArea : NSTrackingArea?
	
	var moveAnchor: NSPoint!
	var originalPosition: NSPoint!
	weak var highlightedAnnotation: Annotation?
	
	// annotation creation properties
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
	
	var controlHighlightColour: NSColor {
		get {
			return controlColour.highlight(withLevel: 0.1)!
		}
	}
	
	// this will make exporting sooo much easier later
	override var isFlipped: Bool {
		return true
	}
	
	override var acceptsFirstResponder: Bool {
		return true
	}
	
	// reference to our currently active object's annotations array
	weak var object: PhotoAnnotation? {
		didSet {
			guard let object = object,
				let image = delegate?.annotationPhotoRequested(for: object)
				else {
					self.image = nil
					return
			}
			
			DispatchQueue.main.async {
				// update our image view
				self.image = image
				let size = image.size
				
				// make sure that our image view matches the image's size
				self.frame.size = size

				// also, make sure our UI scales well with the image
				let scale = (size.width + size.height) / 1000

				self.annotationUIScale = scale
				self.annotationLineThickness = 4.0 * scale
				self.annotationLabelSize = 12.0 * scale
				self.annotationMinArea = Float(16.0 * scale)
				
				// finally, make sure that the entire image is visible when it has been selected
				self.enclosingScrollView?.magnify(toFit: self.frame)
			}
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
	
	// MARK: View Set Up
	
	/// from https://stackoverflow.com/questions/7543684/mousemoved-not-called
	
	override func updateTrackingAreas() {
		if trackingArea != nil {
            self.removeTrackingArea(trackingArea!)
        }
		
		let options : NSTrackingArea.Options =
            [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow]
		
        trackingArea = NSTrackingArea(rect: self.bounds, options: options,
                                      owner: self, userInfo: nil)
		
        self.addTrackingArea(trackingArea!)
	}
	
	// MARK: Drawing

	private func draw(rect: CGRect) {
		let path = NSBezierPath.init(rect: rect)
		path.lineWidth = annotationLineThickness
		path.lineCapStyle = .round
		path.lineJoinStyle = .bevel
		path.stroke()
	}
	
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

		guard let object = object else {
			return
		}
		
		// annotation "preview"
		
		controlColour.setStroke()
		
		if let start = start {
			let rect = CGRect(x: start.x, y: start.y, width: CGFloat(w), height: CGFloat(h))
			draw(rect: rect)
		}
		
		for annotation in object.annotations {
			// only draw visible annotations
			guard NSIntersectsRect(dirtyRect, annotation.cgRect) else {
				continue
			}
			
			var isSelected = false
			
			if let active = highlightedAnnotation, active == annotation {
				isSelected = true
			}
						
			// annotation outline
			isSelected ? controlHighlightColour.setStroke() : controlColour.setStroke()
		
			draw(rect: annotation.cgRect)
			
			// label BG
			isSelected ? controlHighlightColour.setFill() : controlColour.setFill()
			
			var labelBG = annotation.cgRect
			labelBG.size.height = annotationLabelSize + (12 * annotationUIScale)
			
			let bgPath = NSBezierPath.init(rect: labelBG)
			bgPath.fill()
			
			// label
			var label = NSString(string: annotation.label)
			var point = annotation.cgRect.origin
			
			// dragging indicator
			if isSelected && state == .dragMode {
				label = NSString(string: "DrML".l)
			}
			
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
		
		let cursor = convert(event.locationInWindow, from: nil)
		
		switch state {
			
		case .normal:
			start = cursor
			
		default:
			break
		}
	}
	
	override func mouseMoved(with event: NSEvent) {
		
		guard let object = object else {
			state = .normal
			return
		}
		
		let cursor = convert(event.locationInWindow, from: nil)
		
		// if a user moves their cursor over an annotation, we can enter "drag" mode
		
		for annotation in object.annotations {
			if NSPointInRect(cursor, annotation.cgRect) {
				state = .canEnterDragMode
				highlightedAnnotation = annotation
				setNeedsDisplay()
				return
			}
		}
		
		state = .normal
		highlightedAnnotation = nil
		setNeedsDisplay()
	}
	
	override func mouseDragged(with event: NSEvent) {
		
		let cursor = convert(event.locationInWindow, from: nil)
		
		switch state {
			
		case .normal:
			updateSize(with: event)
			
		case .canEnterDragMode:
			state = .dragMode
			originalPosition = highlightedAnnotation?.cgRect.origin
			moveAnchor = cursor
			
		case .dragMode:
			let deltaX = CGFloat(moveAnchor.x - cursor.x)
			let deltaY = CGFloat(moveAnchor.y - cursor.y)
			
			highlightedAnnotation?.x = Float(originalPosition.x - deltaX)
			highlightedAnnotation?.y = Float(originalPosition.y - deltaY)
			
			break
		} 
		
		self.setNeedsDisplay()
	}
	
	override func mouseUp(with event: NSEvent) {
		
		let a = abs(w * h)
		
		guard object != nil, a > annotationMinArea, let start = start else {
			
			if state != .dragMode {
				// if the annotation box area is less than 16 assume that the user is selecting
				findClickedAnnotation(in: event)
			}
			
			// end of drag-move
			if state == .dragMode {
				state = .normal
				highlightedAnnotation = nil
			}
			
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
