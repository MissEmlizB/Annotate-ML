//
//  SplitViewController.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 08/07/2020.
//  Copyright © 2020 Emily Blackwell. All rights reserved.
//

import Cocoa


class SplitViewController: NSSplitViewController {
	
	weak var sidebar: SidebarViewController!
	weak var editor: ViewController!
	
	var document: Document! {
		didSet {
			editor.document = self.document
			self.document.delegate = editor
		}
	}
	
	private func getViewControllers() {
		
		for item in self.splitViewItems {
			
			let viewController = item.viewController
			
			if viewController is SidebarViewController {
				self.sidebar = (viewController as! SidebarViewController)
			}
			else if viewController is ViewController {
				self.editor = (viewController as! ViewController)
			}
		}
	}
	
    override func viewDidLoad() {
     
		super.viewDidLoad()
		
		// Set up our view controllers
		self.getViewControllers()
		editor.photosTableView = sidebar.tableView
	}
}
