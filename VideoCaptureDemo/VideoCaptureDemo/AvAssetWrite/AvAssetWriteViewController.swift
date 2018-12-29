//
//  AvAssetWriteViewController.swift
//  VideoCaptureDemo
//
//  Created by Avazu Holding on 2018/12/25.
//  Copyright © 2018 Avazu Holding. All rights reserved.
//

import UIKit

class AvAssetWriteViewController: UIViewController,AVAssetWriterManagerDelegate {
	func updateProgress(progress: CGFloat) {
		print("progress = \(progress)")
	}
	

	lazy var assetWriteManager: AvAssetWriteManager = {

		return AvAssetWriteManager.init(supview: view)
	}()
	
    override func viewDidLoad() {
        super.viewDidLoad()

		assetWriteManager.delegate = self
    }
	

	@IBAction func back(_ sender: Any) {
		self.dismiss(animated: true, completion: nil)
	}
	@IBAction func startRecord(_ sender: Any) {
		assetWriteManager.startRecord()
	}
	@IBAction func stopRecor(_ sender: Any) {
		assetWriteManager.stopRecord()
	}
	@IBAction func switchPosition(_ sender: Any) {
		assetWriteManager.turnCameraAction()
	}
	@IBAction func reset(_ sender: Any) {
		assetWriteManager.reset()
	}
}
