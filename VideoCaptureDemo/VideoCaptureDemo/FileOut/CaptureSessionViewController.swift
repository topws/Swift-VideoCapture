//
//  CaptureSessionViewController.swift
//  VideoCaptureDemo
//
//  Created by Avazu Holding on 2018/12/14.
//  Copyright © 2018 Avazu Holding. All rights reserved.
//

import UIKit
import AVFoundation

class CaptureSessionViewController: UIViewController {
	
	lazy var manager: FileOutManager = {
		return FileOutManager.init(supview: view)
	}()
	
	@IBAction func clickback(_ sender: UIButton) {
		self.dismiss(animated: true, completion: nil)
	}
	@IBAction func clickRecord(_ sender: UIButton) {
		
		manager.startRecord()
	}
	@IBAction func stopRecord(_ sender: UIButton) {
		manager.stopRecord()
	}
	@IBAction func turnCamera(_ sender: UIButton) {
		manager.turnCameraAction()
	}
	override func viewDidLoad() {
		super.viewDidLoad()
		
	}
	
	
	
}
