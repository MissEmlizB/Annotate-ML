//
//  PreferencesViewController.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 06/11/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa

// preferences keys
let kPreferencesSuggestionsEnabled = "suggestionsEnabled"
let kPreferencesCalendarStyleTitlebar = "combinedTitleBarAndToolBarAppearance"
let kPreferencesShowsImageSize = "showsImageSize"

class PreferencesViewController: NSViewController {

	/// This is posted whenever the user changes something in the preferences window
	static let preferencesChanged = NSNotification.Name(rawValue: "preferencesWereChanged")
	
	private let defaults = UserDefaults.standard
	
	@IBOutlet weak var suggestionsCheckbox: NSButton!
	@IBOutlet weak var caltoolbarCheckbox: NSButton!
	@IBOutlet weak var imageSizeCheckbox: NSButton!
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
        // update our UI to match the user's preferences
		setState(of: suggestionsCheckbox, forKey: kPreferencesSuggestionsEnabled, default: false)
		
		setState(of: caltoolbarCheckbox, forKey: kPreferencesCalendarStyleTitlebar, default: false)
		
		setState(of: imageSizeCheckbox, forKey: kPreferencesShowsImageSize, default: true)
    }
	
	// MARK: Actions
	
	private func setState(of checkbox: NSButton, forKey key: String, default value: Bool) {
		
		// if it wasn't registered yet, set it to its default value
		if defaults.object(forKey: key) == nil {
			defaults.set(value, forKey: key)
		}
		
		// update our checkbox to match
		checkbox.state = defaults.bool(forKey: key) ? .on : .off
	}
	
	@IBAction func checkboxChanged(sender: NSButton) {
		
		var changes: [String: Bool] = [:]
		let tag = sender.tag
		let isChecked = sender.state == .on
		
		switch tag {
		
		// show suggestions in labels editor
		case 0:
			changes[kPreferencesSuggestionsEnabled] = isChecked
			defaults.set(isChecked, forKey: kPreferencesSuggestionsEnabled)
			
		// combine title bar and tool bar (like in Calendar and Safari)
		case 1:
			changes[kPreferencesCalendarStyleTitlebar] = isChecked
			defaults.set(isChecked, forKey: kPreferencesCalendarStyleTitlebar)
			
		case 2:
			changes[kPreferencesShowsImageSize] = isChecked
			defaults.set(isChecked, forKey: kPreferencesShowsImageSize)
			
		default:
			break
		}
		
		// allow our UI to respond appropriately to the changes
		NotificationCenter.default.post(name: PreferencesViewController.preferencesChanged, object: nil, userInfo: changes)
	}
}
