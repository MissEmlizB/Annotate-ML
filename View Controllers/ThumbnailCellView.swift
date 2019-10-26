//
//  ThumbnailCellView.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 26/10/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa

class ThumbnailCellView: NSTableCellView {
	
	@IBOutlet weak var photo: NSImageView!
	@IBOutlet weak var processingIndicator: NSProgressIndicator!

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}
