//
//  Exporter.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 06/07/2020.
//  Copyright © 2020 Emily Blackwell. All rights reserved.
//

import Foundation

protocol DocumentExporter {
	typealias CompletionHandler = (Bool) -> Void
	func export(url: URL, completion: CompletionHandler?)
}
