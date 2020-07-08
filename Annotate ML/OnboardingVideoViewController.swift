//
//  OnboardingVideoViewController.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 23/11/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa
import AVKit

class OnboardingVideoViewController: NSViewController {

	@IBOutlet weak var videoPlayer: NSView! {
		didSet {
			setUpVideoPlayer()
			
			NC.observe(AppDelegate.appearanceChanged, using: #selector(appearanceChanged(notification:)), on: self)
		}
	}
	
	private var player: AVQueuePlayer!
	private var looper: AVPlayerLooper!
	
	private var lightVideo: AVPlayerItem!
	private var darkVideo: AVPlayerItem!
		
	@IBInspectable var filename: String = ""
	
	var videoItem: AVPlayerItem {
		get {
			if #available(macOS 10.14, *) {
				
				// on Mojave (and later macOS versions), we'll return the video appearance that best matches the system's
				let appearance = NSApp.effectiveAppearance
				
				if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
					return darkVideo
				}
			}
			
			// High Sierra always uses the light video
			return lightVideo
		}
	}

	// MARK: Actions

	private func setUpVideoPlayer() {
		
		// load the light and dark variants of the specified video
		let bundle = Bundle.main
					
		guard let lightVideoURL = bundle.url(forResource: "\(filename) - Light", withExtension: "m4v"),
			let darkVideoURL = bundle.url(forResource: "\(filename) - Dark", withExtension: "m4v") else {

				return
		}
		
		player = AVQueuePlayer()
		
		lightVideo = AVPlayerItem(url: lightVideoURL)
		darkVideo = AVPlayerItem(url: darkVideoURL)
				
		// set up our layers
		let playerLayer = AVPlayerLayer(player: player)
		playerLayer.frame.size = videoPlayer.frame.size
		
		videoPlayer.wantsLayer = true
		videoPlayer.layer!.addSublayer(playerLayer)
		
		looper = AVPlayerLooper(player: player, templateItem: videoItem)
		player.play()
	}
	
	// MARK: Notification Centre
	@objc func appearanceChanged(notification: NSNotification) {
		
		if #available(macOS 10.14, *) {
			// if you don't know where this is from, you're seriously missing out
			// I had tried to forget all the pain and regret
			let itsTheLastTime = player.currentTime()
			
			// stop the current video
			player.pause()
			looper.disableLooping()
			player.removeAllItems()
			
			// switch to the appropriate video appearance
			looper = AVPlayerLooper(player: player, templateItem: videoItem)
			
			// seek to its previous position
			player.seek(to: itsTheLastTime)
			player.play()
		}
	}
}
