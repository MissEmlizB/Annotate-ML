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

class PreferencesViewController: NSViewController {

	/// This is posted whenever the user changes something in the preferences window
	static let preferencesChanged = NSNotification.Name(rawValue: "preferencesWereChanged")
	
	private let defaults = UserDefaults.standard
	
	@IBOutlet weak var suggestionsCheckbox: NSButton!
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
        // update our UI to match the user's preferences
		setState(of: suggestionsCheckbox, forKey: kPreferencesSuggestionsEnabled, default: false)
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
		var changes: [String: Any] = [:]
		let tag = sender.tag
		let isChecked = sender.state == .on
		
		switch tag {
			
		case 0:
			changes[kPreferencesSuggestionsEnabled] = isChecked
			defaults.set(isChecked, forKey: kPreferencesSuggestionsEnabled)
			
		default:
			break
		}
		
		// allow our UI to respond appropriately to the changes
		NotificationCenter.default.post(name: PreferencesViewController.preferencesChanged, object: nil, userInfo: changes)
	}
}
