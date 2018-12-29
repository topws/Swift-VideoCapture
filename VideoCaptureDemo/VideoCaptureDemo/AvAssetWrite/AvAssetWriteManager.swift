//
//  AvAssetWriteManager.swift
//  VideoCaptureDemo
//
//  Created by Avazu Holding on 2018/12/25.
//  Copyright © 2018 Avazu Holding. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

protocol AVAssetWriterManagerDelegate: NSObjectProtocol {
	func updateProgress(progress: CGFloat)
}
class AvAssetWriteManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate,DataWriterManagerDelegate {
	func finishWriting() {
		session.stopRunning()
		recordState = .finish
	}
	
	func updateWritingProgress(progress: CGFloat) {
		print("progress = \(progress)")
		if delegate != nil {
			delegate!.updateProgress(progress: progress)
		}
	}
	
	//MARK: ---Delegate
	func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		
	}
	func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		autoreleasepool {
			
			//video
			if connection == videoOutput.connection(with: .video) {
				
				if writerManager?.videoFormatDesc == nil {
					if lock.try() {
						writerManager?.videoFormatDesc = CMSampleBufferGetFormatDescription(sampleBuffer)
						lock.unlock()
					}
					
				}else {
					if lock.try() {
						if writerManager?.writeState == .recording {
							writerManager?.appendSampleBuffer(sampleBuffer: sampleBuffer, mediaType: AVMediaType.video)
						}
						lock.unlock()
					}
				}
			}
			//audio
			if connection == audioOutput.connection(with: .audio) {
				
				if writerManager?.audioFormatDesc == nil {
					if lock.try() {
						writerManager?.audioFormatDesc = CMSampleBufferGetFormatDescription(sampleBuffer)
						lock.unlock()
					}
					
				}else {
					if lock.try() {
						if writerManager?.writeState == .recording {
							writerManager?.appendSampleBuffer(sampleBuffer: sampleBuffer, mediaType: AVMediaType.audio)
						}
						lock.unlock()
					}
				}
			}
			
		}
	}
	
	//MARK: ----- property
	var recordVideoFolder: String {
		if let path = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first {
			let direc = NSString(string: path).appendingPathComponent("fileoutVideo") as String
			if !FileManager.default.fileExists(atPath: direc) {
				try? FileManager.default.createDirectory(atPath: direc, withIntermediateDirectories: true, attributes: [:])
			}
			return direc
		}
		return ""
	}
	
	lazy private var session: AVCaptureSession = {
		let session = AVCaptureSession()
		if session.canSetSessionPreset(.high) {
			session.sessionPreset = .high
		}
		return session
	}()
	private var videoInput: AVCaptureDeviceInput?
	private var audioInput: AVCaptureDeviceInput?
//	private var fileOutPut: AVCaptureMovieFileOutput = AVCaptureMovieFileOutput()
	private var videoOutput: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
	private var audioOutput: AVCaptureAudioDataOutput = AVCaptureAudioDataOutput()
	private var writerManager: DataWriterManager?
	private var videoUrl: URL{
		let videoName = String.init(format: "%@.mp4", UUID().uuidString)
		let videoPath = NSString(string: recordVideoFolder).appendingPathComponent(videoName) as String
		
		return  URL.init(fileURLWithPath: videoPath)
	}
	private let videoQueue: DispatchQueue = DispatchQueue.init(label: "com.dotc.avassetwriter")
	private let lock: NSLock = NSLock()
	private var layerSuperView: UIView?
	lazy private var previewLayer: AVCaptureVideoPreviewLayer = {
		let preLayer = AVCaptureVideoPreviewLayer.init(session: session)
		preLayer.videoGravity = .resizeAspectFill
		return preLayer
	}()
	
	init(supview: UIView) {
		
		layerSuperView = supview
		super.init()
		setUp()
	}
	//MARK: --public---
	var recordState: RecordState = .initing
	weak var delegate: AVAssetWriterManagerDelegate?
	func startRecord() {
		//write data to file
		if recordState == .initing {
			writerManager?.startWrite()
			recordState = .recording
		}
		
	}
	func stopRecord() {
		writerManager?.stopWrite()
		session.stopRunning()
		recordState = .finish
	}
	func reset() {
		recordState = .initing
		session.startRunning()
		setUpWriter()
	}
	func destroy() {
		session.stopRunning()
//		session = nil
//		videoQueue = nil
//		videoOutput = nil
//		videoInput = nil
//		audioOutput = nil
//		audioInput = nil
//		writerManager.destroyWriter()
	}
	func turnCameraAction() {
		session.stopRunning()
		
		var position = videoInput?.device.position
		if position == AVCaptureDevice.Position.back {
			position = AVCaptureDevice.Position.front
		}else {
			position = AVCaptureDevice.Position.back
		}
		if let device = getCameraDevice(position: position!) {
			if let newInput = try? AVCaptureDeviceInput.init(device: device) {
				session.beginConfiguration()
				if videoInput != nil {
					session.removeInput(videoInput!)
				}
				session.addInput(newInput)
				session.commitConfiguration()
				videoInput = newInput
				
				session.startRunning()
			}
		}
	}
	
	private func setUp() {
		//session
		
		//addVideoInput
		if let videoDevice = getCameraDevice(position: .back) {
			if let videoInput = try? AVCaptureDeviceInput.init(device: videoDevice) {
				if session.canAddInput(videoInput) {
					session.addInput(videoInput)
					self.videoInput = videoInput
				}
			}
		}
		//addVideoutPutdata
		videoOutput.alwaysDiscardsLateVideoFrames = true
		videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
		if session.canAddOutput(videoOutput) {
			session.addOutput(videoOutput)
		}
		
		//addAudioInput
		if let audioDevice = AVCaptureDevice.default(for: .audio) {
			if let audioInput = try? AVCaptureDeviceInput.init(device: audioDevice) {
				if session.canAddInput(audioInput) {
					session.addInput(audioInput)
					self.audioInput = audioInput
				}
				
			}
		}
		//addAudioOutputdata
		audioOutput.setSampleBufferDelegate(self, queue: videoQueue)
		if session.canAddOutput(audioOutput) {
			session.addOutput(audioOutput)
		}
		//previewLayer
		previewLayer.frame = CGRect.init(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
		layerSuperView?.layer.insertSublayer(previewLayer, at: 0)
		
		//
//		session.commitConfiguration()
		
		//开始采集画面
		session.startRunning()
		
		///set dataWriterManager
		setUpWriter()
		
	}
	private func setUpWriter() {
		writerManager = DataWriterManager.init(url: videoUrl)
		writerManager?.delegate = self
	}
	private func getCameraDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
		
		if #available (iOS 10, *){
			return AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: position)
		}else {
			return AVCaptureDevice.devices(for: .video).filter({return ($0.position == position)}).first
		}
	}
	deinit {
		destroy()
	}
}
