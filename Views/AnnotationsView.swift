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
	case resizeMode
}

protocol AnnotationsViewDelegate {
	func annotationCreated(annotation: Annotation)
	func annotationSelected(annotation: Annotation, at: NSPoint)
	func annotationPhotoRequested(for object: PhotoAnnotation) -> NSImage?
	
	func annotationImageSizeAvailable(size: NSSize)
	
	func annotationActionUndone()
	func annotationActionRedone()
}

class AnnotationsView: NSImageView {

	var delegate: AnnotationsViewDelegate?
	var state: AnnotationsViewState = .normal
	
	// modification variables
	var trackingArea : NSTrackingArea?
	var moveAnchor: NSPoint?
	
	// moving variables
	var originalPosition: NSPoint!
	weak var highlightedAnnotation: Annotation?
	
	// resizing variables
	var originalRect: NSRect!

	// (-1 = none, 0 = tl, 1 = tr, 2 = bl, 3 = br)
	var highlightedHandle = -1
	
	// annotation creation properties
	var start: NSPoint!
	var w: Float = 0
	var h: Float = 0
	
	// UI Scaling
	private var annotationLineThickness: CGFloat = 4.0
	private var annotationBGOffset: CGFloat = 2.0
	private var annotationLabelSize: CGFloat = 12.0
	private var annotationUIScale: CGFloat = 1.0
	private var annotationMinArea: Float = 16

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
				
				// Update our image view
				self.image = image
				
				let imageRep = image.representations.first!
				
				// The actual photo size
				let size = NSSize(width: imageRep.pixelsWide, height: imageRep.pixelsHigh)
				
				// Size scaled for the user's screen
				let scaledSize = image.size
				
				self.delegate?.annotationImageSizeAvailable(size: size)
				
				// Make sure that our image view matches the image's real size
				self.frame.size = size

				// Also, make sure our UI scales well with the image
				let scale = (scaledSize.width + scaledSize.height) / 1000

				self.annotationUIScale = scale
				self.annotationLineThickness = 4.0 * scale
				self.annotationLabelSize = 12.0 * scale
				self.annotationMinArea = Float(16.0 * scale)
				
				self.annotationBGOffset = self.annotationLineThickness / 2
				
				// Make sure that the entire image is visible
				self.enclosingScrollView?.magnify(toFit: self.frame)
			}
		}
	}
	
	func setup() {
		NC.observe(LabelsViewController.labelRenamed, using: #selector(labelWasRenamed(notfication:)), on: self)
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

	private func drawOutline(rect: CGRect) {
		let path = NSBezierPath.init(rect: rect)
		path.lineWidth = annotationLineThickness
		path.lineCapStyle = .round
		path.lineJoinStyle = .bevel
		path.stroke()
	}
	
	private func drawHandles(in rect: NSRect) {
		
		let handles = rect.getAllHandles(withScale: annotationUIScale)
		
		for (i, handle) in handles.enumerated() {
			
			// highlight the selected handle
			highlightedHandle == i ? handleHighlightColour.setFill() : handleColour.setFill()
			
			handle.fill()
		}
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
			drawOutline(rect: rect)
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
		
			drawOutline(rect: annotation.cgRect)
			
			// label BG
			isSelected ? controlHighlightColour.setFill() : controlColour.setFill()
			
			var labelBG = annotation.cgRect
			labelBG.size.height = annotationLabelSize + (12 * annotationUIScale)
			
			// make sure the outline and the label background won't overlap
			labelBG.origin.x += annotationBGOffset
			labelBG.origin.y += annotationBGOffset
			labelBG.size.width -= annotationLineThickness
			
			let bgPath = NSBezierPath.init(rect: labelBG)
			bgPath.lineCapStyle = .round
			bgPath.lineJoinStyle = .bevel
			bgPath.fill()
			
			// label
			let label = NSString(string: annotation.label)
			var point = annotation.cgRect.origin
			
			let padding = 4 * annotationUIScale
			point.x += padding
			point.y += padding
			
			label.draw(at: point, withAttributes: [.font: NSFont.labelFont(ofSize: annotationLabelSize), .foregroundColor: controlColour.bestForeground])
			
			// show resize handles when it's selected
			if isSelected {
				drawHandles(in: annotation.cgRect)
			}
		}
    }
	
	// MARK: Colours
	
	var controlColour: NSColor {
		var colour: NSColor!
		
		if #available(macOS 10.14, *) {
			colour = .controlAccentColor
		} else {
			colour = .systemBlue
		}
		
		return colour.withAlphaComponent(0.8)
	}

	var handleColour: NSColor {
		return controlColour
			.shadow(withLevel: 0.3)!
			.withAlphaComponent(0.5)
	}
	
	var controlHighlightColour: NSColor {
		return controlColour.highlight(withLevel: 0.1)!
			.withAlphaComponent(1.0)
	}
	
	var handleHighlightColour: NSColor {
		return handleColour.highlight(withLevel: 0.1)!
			.withAlphaComponent(1.0)
	}
}

extension AnnotationsView {
	
	// MARK: Annotation Creation
	
	private func updateSize(with event: NSEvent) {
		guard let start = self.start else {
			return
		}
		
		let end = convert(event.locationInWindow, from: nil)
		
		w = Float(end.x - start.x)
		h = Float(end.y - start.y)
	}
	
	override func mouseMoved(with event: NSEvent) {
		
		guard let object = object else {
			state = .normal
			highlightedHandle = -1
			highlightedAnnotation = nil
		
			return
		}
		
		let cursor = convert(event.locationInWindow, from: nil)
					
		// try to find handles under the cursor
		if state == .canEnterDragMode {
			if let activeAnnotation = highlightedAnnotation {
				
				highlightedHandle = -1
				let handles = activeAnnotation.cgRect.getAllHandles(withScale: annotationUIScale)
				
				for (corner, handle) in handles.enumerated() {
					if NSPointInRect(cursor, handle) {
						highlightedHandle = corner
						setNeedsDisplay()
						
						// resizing cursor
						NSCursor.resizeLeftRight.set()

						return
					}
				}
				
				highlightedHandle = -1
				setNeedsDisplay()
			}
		}
		
		// try to find annotations under the cursor
		for annotation in object.annotations {
			if NSPointInRect(cursor, annotation.cgRect) {
				state = .canEnterDragMode
				highlightedAnnotation = annotation
				setNeedsDisplay()

				// moving cursor
				NSCursor.openHand.set()
				
				return
			}
		}
		
		//
		NSCursor.crosshair.set()
		
		state = .normal
		highlightedAnnotation = nil
		setNeedsDisplay()
	}
	
	override func mouseDown(with event: NSEvent) {
		
		let cursor = convert(event.locationInWindow, from: nil)
		
		switch state {
			
		case .normal:
			if highlightedAnnotation == nil {
				start = cursor
				
				// drawing cursor
				NSCursor.crosshair.set()
				return
			}
		
		case .canEnterDragMode, .resizeMode:
			NSCursor.closedHand.set()
			
		default:
			break
		}
	}
	
	override func mouseDragged(with event: NSEvent) {
		
		let cursor = convert(event.locationInWindow, from: nil)
		
		let deltaX = CGFloat((moveAnchor?.x ?? 0) - cursor.x)
		let deltaY = CGFloat((moveAnchor?.y ?? 0) - cursor.y)
		
		switch state {
			
		case .normal:
			updateSize(with: event)
			
		case .canEnterDragMode:
			
			if highlightedHandle == -1 {
				state = .dragMode
				originalPosition = highlightedAnnotation!.cgRect.origin
			} else {
				state = .resizeMode
				originalRect = highlightedAnnotation!.cgRect
			}
			
			moveAnchor = cursor
			
		case .dragMode:
			move(x: deltaX, y: deltaY)
			
		case .resizeMode:
			resize(x: deltaX, y: deltaY)
		} 
		
		self.setNeedsDisplay()
	}
	
	override func mouseUp(with event: NSEvent) {
		
		NSCursor.crosshair.set()
		
		let a = abs(w * h)
		
		guard object != nil, a > annotationMinArea, let start = start else {
			
			if state != .dragMode && state != .resizeMode {
				// if the annotation box area is less than 16 assume that the user is selecting
				findClickedAnnotation(in: event)
			}
			
			// end of drag actions
			if state == .dragMode || state == .resizeMode {
				
				if state == .resizeMode {
					resizeAnnotation(annotation: highlightedAnnotation!, withRect: highlightedAnnotation!.cgRect, oldRect: self.originalRect)
				}
				
				else {
					let newPosition = CGPoint(x: CGFloat(highlightedAnnotation!.x),
											  y: CGFloat(highlightedAnnotation!.y))
					
					moveAnnotation(annotation: highlightedAnnotation!, oldPosition: originalPosition, newPosition: newPosition)
				}
				
				state = .normal
				highlightedAnnotation = nil
			}
	
			self.start = nil
			self.setNeedsDisplay()
			
			return
		}
		
		updateSize(with: event)
				
		let rect = CGRect(x: start.x, y: start.y, width: CGFloat(w), height: CGFloat(h)).standardized
		
		// we don't need these anymore
		self.start = nil
		w = 0
		h = 0
			
		// create and select our new annotation
		let annotation = createAnnotation(withRect: rect)
		self.delegate?.annotationSelected(annotation: annotation, at: annotation.cgRect.origin)
	}
	
	override func mouseEntered(with event: NSEvent) {
		super.mouseEntered(with: event)
		NSCursor.crosshair.set()
	}
	
	override func mouseExited(with event: NSEvent) {
		super.mouseExited(with: event)
		NSCursor.arrow.set()
	}
}

extension AnnotationsView {
	
	private func isBelowMinArea(_ f: Float) -> Bool {
		return f < annotationMinArea
	}
	
	/// prevents the annotation box from getting smaller than the minimum area
	private func keepBoxSize() {
		guard highlightedAnnotation != nil else {
			return
		}
		
		if isBelowMinArea(highlightedAnnotation!.w) {
			highlightedAnnotation!.w = annotationMinArea
		}
		
		if isBelowMinArea(highlightedAnnotation!.h) {
			highlightedAnnotation!.h = annotationMinArea
		}
	}
	
	// MARK: Actions
	
	private func move(x deltaX: CGFloat, y deltaY: CGFloat) {
		highlightedAnnotation!.x = Float(originalPosition.x - deltaX)
		highlightedAnnotation!.y = Float(originalPosition.y - deltaY)
	}
	
	private func resize(x deltaX: CGFloat, y deltaY: CGFloat) {
		
		switch highlightedHandle {
				
			// top left
			case 0:
				highlightedAnnotation!.x = Float(originalRect.origin.x - deltaX)
				highlightedAnnotation!.y = Float(originalRect.origin.y - deltaY)
				highlightedAnnotation!.w = Float(originalRect.width + deltaX)
				highlightedAnnotation!.h = Float(originalRect.height + deltaY)
			
			// top right
			case 1:
				highlightedAnnotation!.w = Float(originalRect.width - deltaX)
				highlightedAnnotation!.y = Float(originalRect.origin.y - deltaY)
				highlightedAnnotation!.h = Float(originalRect.height + deltaY)
			
			// bottom left
			case 2:
				highlightedAnnotation!.x = Float(originalRect.origin.x - deltaX)
				// highlightedAnnotation!.y = Float(originalRect.origin.y + deltaY)
				highlightedAnnotation!.w = Float(originalRect.width + deltaX)
				highlightedAnnotation!.h = Float(originalRect.height - deltaY)
			
			// bottom right (aka. my favourite resize handle)
			case 3:
				highlightedAnnotation!.w = Float(originalRect.width - deltaX)
				highlightedAnnotation!.h = Float(originalRect.height - deltaY)
				
			default:
				break
		}
		
		keepBoxSize()
	}
}

extension AnnotationsView {
	
	// MARK: Notification Centre
	
	@objc func labelWasRenamed(notfication: NSNotification) {
		self.setNeedsDisplay()
	}
}

extension AnnotationsView {
	
	private func findMissing(annotation: Annotation?, withRectToMatch rect: CGRect) -> Annotation? {
		
		// if our annotation is not nil then return itself
		guard annotation == nil else {
			return annotation
		}
		
		// otherwise, search our active object's annotations for a possible match
		guard let object = self.object else {
			return nil
		}
		
		for anno in object.annotations {
			if anno.cgRect == rect {
				return anno
			}
		}
		
		// it doesn't exist anymore... HOW???
		// we shouldn't return this in a normal undo/redo action
		
		return nil
	}
	
	// MARK: Undo Actions
	
	func renameAnnotation(annotation: Annotation?, old: String, new: String) {
		guard let annotation = annotation else {
			return
		}
		
		setNeedsDisplay()
		annotation.label = new
				
		undoManager?.registerUndo(withTarget: self) {
						
			$0.undoManager?.registerUndo(withTarget: $0) {
				$0.renameAnnotation(annotation: annotation, old: old, new: new)
				$0.delegate?.annotationActionRedone()
			}
			
			annotation.label = old
			$0.setNeedsDisplay()
			
			$0.delegate?.annotationActionUndone()
		}
		
		undoManager?.setActionName("uAREN".l)
	}
	
	func deleteAnnotation(position: Int) {
		guard let object = self.object else {
			return
		}
		
		let annotation = object.annotations[position]
		
		object.annotations.remove(at: position)
		setNeedsDisplay()
	
		undoManager?.registerUndo(withTarget: self) {
			
			$0.undoManager?.registerUndo(withTarget: $0) {
				$0.deleteAnnotation(position: position)
			}
			
			object.annotations.insert(annotation, at: position)
			$0.setNeedsDisplay()
		}
		
		undoManager?.setActionName("uADEL".l)
	}
	
	private func createAnnotation(withRect rect: CGRect, object oannotation: Annotation? = nil) -> Annotation {
		
		var annotation: Annotation!
		
		if oannotation == nil {
			// create a new annotation object
			annotation = Annotation(rect: rect)
			delegate?.annotationCreated(annotation: annotation)
		} else {
			// since this is a redo operation, we'll just insert the original annotation back to our list
			annotation = oannotation!
		}
		
		object?.annotations.append(annotation)
		setNeedsDisplay()
		
		// register our undo action
		undoManager?.registerUndo(withTarget: self) {
						
			$0.undoManager?.registerUndo(withTarget: $0) {
				let _ = $0.createAnnotation(withRect: rect, object: annotation)
				$0.delegate?.annotationActionRedone()
			}
			
			$0.delegate?.annotationActionUndone()
			$0.object?.annotations.removeAll { $0 == annotation }
			$0.setNeedsDisplay()
		}
		
		undoManager?.setActionName("uACR".l)
		return annotation
	}
	
	private func resizeAnnotation(annotation: Annotation?, withRect newRect: CGRect, oldRect: CGRect) {
		
		guard let annotation = annotation else {
			return
		}
		
		annotation.cgRect = newRect
		setNeedsDisplay()
		
		undoManager?.registerUndo(withTarget: annotation) { _ in
						
			self.undoManager?.registerUndo(withTarget: self) {
				
				weak var annotation = $0.findMissing(annotation: annotation, withRectToMatch: oldRect)
				
				$0.resizeAnnotation(annotation: annotation, withRect: newRect, oldRect: oldRect)
				$0.delegate?.annotationActionRedone()
			}
			
			annotation.cgRect = oldRect
			self.delegate?.annotationActionUndone()
			self.setNeedsDisplay()
		}
		
		undoManager?.setActionName("uAR".l)
	}
	
	private func moveAnnotation(annotation: Annotation?, oldPosition: CGPoint, newPosition: CGPoint) {
		
		guard let annotation = annotation else {
			return
		}
		
		annotation.x = Float(newPosition.x)
		annotation.y = Float(newPosition.y)
		
		setNeedsDisplay()
		
		undoManager?.registerUndo(withTarget: annotation) { _ in
						
			self.undoManager?.registerUndo(withTarget: self) {
								
				$0.moveAnnotation(annotation: annotation, oldPosition: oldPosition, newPosition: newPosition)
				$0.delegate?.annotationActionRedone()
			}
			
			annotation.x = Float(oldPosition.x)
			annotation.y = Float(oldPosition.y)
			
			self.setNeedsDisplay()
			self.delegate?.annotationActionUndone()
		}
		
		undoManager?.setActionName("uAM".l)
	}
}
