//
//  TuriExporter.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 06/07/2020.
//  Copyright © 2020 Emily Blackwell. All rights reserved.
//

import Cocoa

class TuriExporter: CreateMLExporter {
	
	// MARK: Tasks
	
	override func _exportObjects(url: URL, completion: CreateMLExporter.CompletionHandler?) {
				
		self._exportCreateDirectory(url: url, completion: completion)
		var csv: [String] = ["path,annotations"]
		
		// export our photos
		self._exportPhotos(url: url) { object, photoName in
			
			var annotations: [[String: Any]] = []
			
			// Scaled width / height
			let w = Float(object.w)
			let h = Float(object.h)
			
			// Real width / height
			let rw = Float(object.rw)
			let rh = Float(object.rh)
			
			// Scaling ratio
			let sw = rw / w
			let sh = rh / h
			
			// Centres
			let cw = (rw - w) / 2
			let ch = (rh - h) / 2
						
			for annotation in object.annotations {
				
				let w = annotation.w
				let h = annotation.h
				
				// Turi Create's x and y properties are the annotation's centre (instead of its top-left anchor)
				let coordinates: [String: Float] = [
					"x": ((annotation.x + (w/2)) - cw) * sw,
					"y": ((annotation.y + (h/2)) - ch) * sh,
					"width": w * sw,
					"height": h * sh
				]
				
				#if DEBUG
					print(coordinates)
					print("Rs: \(rw) x \(rh) Ss: \(w) x \(h)")
				#endif
				
				annotations.append([
					"label": annotation.label,
					"coordinates": coordinates
				])
			}
			
			if let data = try? JSONSerialization.data(withJSONObject: annotations, options: .fragmentsAllowed),
				let json = String(data: data, encoding: .utf8)
			{
				let line = "\(photoName),\(json)"
				csv.append(line)
			}
		}
		
		// Export our Python templates
		do {
			try TemplateWriter.writeFile(filename: "Dataset", extension: "py", toUrl: url) {
				$0.replacingOccurrences(of: "%PATH%", with: url.path)
			}
			
			try TemplateWriter.writeFile(filename: "Visualise", extension: "py", toUrl: url)
			
			try TemplateWriter.writeFile(filename: "Create", extension: "py", toUrl: url)
			
			try TemplateWriter.writeFile(filename: "Requirements", extension: "txt", toUrl: url)
		}
		catch {
			#if DEBUG
				print(error.localizedDescription)
			#endif
			
			completion?(false)
			return
		}
		
		// Export our annotations file
		let object = csv.joined(separator: "\n")
		self._exportFile(url: url, object: object, completion: completion)
	}
	
	override func _exportFile(url: URL, object: Any, completion: CompletionHandler?) {
		
		let fm = FileManager.default
		let csv = object as! String
		
		// write the annotations file
		let annotationsPath = url.appendingPathComponent("annotations.csv").path

		guard let data = csv.data(using: .utf8) else {
			return
		}

		fm.createFile(atPath: annotationsPath, contents: data, attributes: .none)
		completion?(true)
	}
}
