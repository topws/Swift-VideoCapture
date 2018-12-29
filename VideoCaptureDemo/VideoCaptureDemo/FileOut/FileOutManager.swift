//
//  FileOutManager.swift
//  VideoCaptureDemo
//
//  Created by Avazu Holding on 2018/12/17.
//  Copyright © 2018 Avazu Holding. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
//import AssetsLibrary
import Photos
protocol CameraFileOutManagerDelegate {
	
}
class FileOutManager:NSObject,AVCaptureFileOutputRecordingDelegate {
	
	//MARK: -----init
	init(supview: UIView) {
		self.previewSuperview = supview
		super.init()
		
		setup()
	}
	//MARK: 初始化
	private func setup() {
		//0、初始化设置
		//can add observer to cancel record when app enterBackground
		
		//1、创建捕捉会话
//		self.session
		
		//2、设置音视频的输入
		 setUpVideoAndAudio()
		
		//3、输出源设置，这里视频，音频数据会合并到一起输出。在代理方法中可以单独拿到视频或音频数据
		setUpFileOut()
		
		session.commitConfiguration()
		//4、添加视频预览层
		setUpPreviewLayer()
		
		//5、开始采集数据，
		session.startRunning()
	}
	private func setUpPreviewLayer() {
		// 1 * 1
		let rect = CGRect.init(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.width)
		previewLayer.frame = rect
		previewSuperview?.layer.insertSublayer(previewLayer, at: 0)
	}
	private func setUpFileOut() {
		
		//设置防抖
		//视频防抖 是在 iOS 6 和 iPhone 4S 发布时引入的功能。到了 iPhone 6，增加了更强劲和流畅的防抖模式，被称为影院级的视频防抖动。相关的 API 也有所改动 (目前为止并没有在文档中反映出来，不过可以查看头文件）。防抖并不是在捕获设备上配置的，而是在 AVCaptureConnection 上设置。由于不是所有的设备格式都支持全部的防抖模式，所以在实际应用中应事先确认具体的防抖模式是否支持：
		if let captureConnection = fileOutput.connection(with: .video) {
			if captureConnection.isVideoStabilizationSupported {
				captureConnection.preferredVideoStabilizationMode = .auto
			}
			if let orientation = previewLayer.connection {
				captureConnection.videoOrientation = orientation.videoOrientation
			}
		}
		if session.canAddOutput(fileOutput) {
			session.addOutput(fileOutput)
		}
	}
	private func setUpVideoAndAudio() {
		if let captureDevice = getCameraDeviceWithPosition(position: AVCaptureDevice.Position.back)  {
			videoInput = try? AVCaptureDeviceInput.init(device: captureDevice)
			if  videoInput != nil {
				if session.canAddInput(videoInput!) {
					session.addInput(videoInput!)
				}
			}
		}
		if let audioCaptureDevice = AVCaptureDevice.default(for: AVMediaType.audio){
			audioInput = try? AVCaptureDeviceInput.init(device: audioCaptureDevice)
			if audioInput != nil  {
				if session.canAddInput(audioInput!) {
					session.addInput(audioInput!)
				}
			}
		}
	}
	//获取摄像头
	private func getCameraDeviceWithPosition(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
		
		//iOS 10.0以上
		if #available(iOS 10.0, *) {
			return AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: position)
		} else {
			let cameras = AVCaptureDevice.devices(for: .video)
			return cameras.filter({return $0.position == position }).first
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
	
	lazy var session: AVCaptureSession = {
		// 录制5秒钟视频 高画质10M,压缩成中画质 0.5M
		// 录制5秒钟视频 中画质0.5M,压缩成中画质 0.5M
		// 录制5秒钟视频 低画质0.1M,压缩成中画质 0.1M
		// 只有高分辨率的视频才是全屏的，如果想要自定义长宽比，就需要先录制高分辨率，再剪裁，如果录制低分辨率，剪裁的区域不好控制
		let session = AVCaptureSession()
		if session.canSetSessionPreset(AVCaptureSession.Preset.high) {
			session.sessionPreset = .high
		}
		return session
	}()
	private var previewSuperview: UIView?
	private var videoInput: AVCaptureDeviceInput?
	private var audioInput: AVCaptureDeviceInput?
	private let fileOutput: AVCaptureMovieFileOutput = AVCaptureMovieFileOutput()
	lazy var previewLayer: AVCaptureVideoPreviewLayer = {
		let previewLayer = AVCaptureVideoPreviewLayer.init(session: session)
		previewLayer.videoGravity = .resizeAspectFill
		return previewLayer
	}()
	
	//MARK: ------AVCaptureFileOutputDelegate
	func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
		print(#function)
	}
	func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
		print("\(output,outputFileURL.absoluteString,connections)")
		
		//通过AVURLAsset获取资源
		let asset = AVURLAsset(url: outputFileURL)
		let time = asset.duration
		let seconds = ceil(Double(time.value)/Double(time.timescale))
		print("videoSeconds = \(seconds)")
		
		//写入系统相册
		PHPhotoLibrary.shared().performChanges({
			PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
		}, completionHandler: { (isSuccess, error) in
			if isSuccess {
				print("save successed")
			}
		})
	}
	
	//MARK: ------Public
	//switch cameraPosition
	func turnCameraAction() {
		session.stopRunning()
		
		var position = videoInput?.device.position
		if position == AVCaptureDevice.Position.back {
			position = AVCaptureDevice.Position.front
		}else {
			position = AVCaptureDevice.Position.back
		}
		if let device = getCameraDeviceWithPosition(position: position!) {
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
	func startRecord() {
		//write data to file
		let videoName = String.init(format: "%@.mp4", UUID().uuidString)
		let videoPath = NSString(string: recordVideoFolder).appendingPathComponent(videoName) as String
		let url = URL.init(fileURLWithPath: videoPath)
		fileOutput.startRecording(to: url, recordingDelegate: self)
	}
	func stopRecord() {
		fileOutput.stopRecording()
		session.startRunning()
	}
	func reset() {
		session.startRunning()
	}
}

//+ (void)setDevice:(AVCaptureDevice *)device deviceMode:(CICameraDeviceMode *)mode
//{
//	NSError *error = nil;
//	if ([device lockForConfiguration:&error])
//	{
//		//对焦
//		if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:mode.focusMode])
//		{
//			[device setFocusMode:mode.focusMode];
//			[device setFocusPointOfInterest:mode.focusPoint];
//		}
//		//曝光
//		if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:mode.exposureMode])
//		{
//			[device setExposureMode:mode.exposureMode];
//			[device setExposurePointOfInterest:mode.exposurePoint];
//		}
//		//白平衡
//		if ([device isWhiteBalanceModeSupported:mode.whiteBalanceMode])
//		{
//			[device setWhiteBalanceMode:mode.whiteBalanceMode];
//		}
//		//火炬
//		if ([device hasTorch] && [device isTorchModeSupported:mode.torchMode])
//		{
//			[device setTorchMode:mode.torchMode];
//		}
//		[device setSubjectAreaChangeMonitoringEnabled:mode.monitorSubjectAreaChange];
//		[device unlockForConfiguration];
//	}
//	else
//	{
//		NSLog(@"%@", error);
//	}
//}

