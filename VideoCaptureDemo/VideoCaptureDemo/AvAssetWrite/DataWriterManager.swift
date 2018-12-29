//
//  DataWriterManager.swift
//  VideoCaptureDemo
//
//  Created by Avazu Holding on 2018/12/26.
//  Copyright © 2018 Avazu Holding. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import AssetsLibrary
import Photos

enum RecordState: NSInteger {
	case initing
	case prepare
	case recording
	case finish
	case failed
}
@objc protocol DataWriterManagerDelegate: NSObjectProtocol {
	func finishWriting()
	func updateWritingProgress(progress: CGFloat)
}
class DataWriterManager {

	private var videoUrl: URL!
	private var writeQueue: DispatchQueue = DispatchQueue.init(label: "com.dotc.wdManager")
	
	lazy private var assetWriter: AVAssetWriter? = {
		return try? AVAssetWriter.init(url: videoUrl, fileType: AVFileType.mp4)
	}()
	private var assetWriterVideoInput: AVAssetWriterInput?
	private var assetWriterAudioInput: AVAssetWriterInput?
	
	private var videoCompressionSetting: [String:Any]?
	private var audioCompressionSetting: [String:Any]?
	
	private var timer: Timer?
	private var recordTime: CGFloat = 0
	private var isCanWrite: Bool = false
	init(url: URL) {
		videoUrl = url
		outputSize = CGSize.init(width: 320, height: 320)
		
	}
	private let lock = NSLock()
	//MARK: ----public
	var writeState: RecordState = .initing
	var outputSize: CGSize = CGSize.zero
	weak var delegate: DataWriterManagerDelegate?
	var videoFormatDesc: CMFormatDescription?
	var audioFormatDesc: CMFormatDescription?
	func startWrite() {
		writeState = .recording
		setUpWriter()
	}
	func stopWrite() {
		writeState = .finish
		timer?.invalidate()
		timer = nil
		
		if assetWriter != nil && assetWriter?.status == AVAssetWriter.Status.writing {
			writeQueue.async {[weak self] in
				
				guard let strongSelf = self else {
					return
				}
				strongSelf.assetWriter?.finishWriting {
					//写入系统相册
					PHPhotoLibrary.shared().performChanges({
						PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: strongSelf.videoUrl)
					}, completionHandler: { (isSuccess, error) in
						if isSuccess {
							print("save successed")
						}
					})
				}
				//----
			}
		}
	}
	func appendSampleBuffer(sampleBuffer: CMSampleBuffer,mediaType: AVMediaType) {

		if lock.try() {
			if writeState.rawValue < RecordState.recording.rawValue {
				print("not ready yet")
				lock.unlock()
				return
			}
			lock.unlock()
		}
		
		writeQueue.async {[weak self] in
			guard let strongSelf = self else {
				return
			}
			autoreleasepool{
				if strongSelf.lock.try() {
					if strongSelf.writeState.rawValue > RecordState.recording.rawValue {
						print("recordstate finished or failed")
						strongSelf.lock.unlock()
						return
					}
					strongSelf.lock.unlock()
				}
				
				if !strongSelf.isCanWrite && mediaType == AVMediaType.video {
					strongSelf.assetWriter?.startWriting()
					strongSelf.assetWriter?.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
					strongSelf.isCanWrite = true
				}
				if strongSelf.timer != nil {
					DispatchQueue.main.async {
						strongSelf.timer = Timer.init(timeInterval: 0.05, target: strongSelf, selector: #selector(strongSelf.updateProgress), userInfo: nil, repeats: true)
						
					}
				}
				//开始写入视频
				if mediaType == AVMediaType.video && strongSelf.assetWriterVideoInput != nil {
					if strongSelf.assetWriterVideoInput!.isReadyForMoreMediaData {
						let flag = strongSelf.assetWriterVideoInput!.append(sampleBuffer)
						if !flag {
							print("video record failed")
							if strongSelf.lock.try() {
								strongSelf.stopWrite()
								strongSelf.destroyWriter()
								strongSelf.lock.unlock()
							}
						}
					}
				}
				//audio
				if mediaType == AVMediaType.audio && strongSelf.assetWriterAudioInput != nil {
					if strongSelf.assetWriterAudioInput!.isReadyForMoreMediaData {
						let flag = strongSelf.assetWriterAudioInput!.append(sampleBuffer)
						if !flag {
							print("video record failed")
							if strongSelf.lock.try() {
								strongSelf.stopWrite()
								strongSelf.destroyWriter()
								strongSelf.lock.unlock()
							}
						}
					}
				}
			}
		}
		
	}
	@objc private func updateProgress() {
		if  recordTime >= 8.0 {
			stopWrite()
			
			if delegate != nil {
				delegate!.finishWriting()
			}
			return
		}
		recordTime += 0.05
		if delegate != nil  {
			delegate!.updateWritingProgress(progress: recordTime/8.0)
		}
	}
	private func setUpWriter() {
		
		//写入视频大小
		let numPixels: NSInteger = NSInteger(outputSize.width * outputSize.height)
		//每像素比特
		let bitsPerPixel: CGFloat = 6.0
		let bitsPerSecond: NSInteger = numPixels * NSInteger(bitsPerPixel)
		
		//码率和帧率设置
		let compressionProperties = [AVVideoAverageBitRateKey : NSNumber.init(value: bitsPerSecond),
									 AVVideoExpectedSourceFrameRateKey : (30 as NSNumber),
									 AVVideoMaxKeyFrameIntervalKey : NSNumber.init(value:30),
									 AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel] as [String : Any]
		
		videoCompressionSetting = [AVVideoCodecKey : AVVideoCodecH264,
								   AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
								   AVVideoWidthKey : NSNumber.init(value: Int(outputSize.height)),
								   AVVideoHeightKey : NSNumber.init(value: Int(outputSize.width)),
								   AVVideoCompressionPropertiesKey : compressionProperties]
		
		assetWriterVideoInput = AVAssetWriterInput.init(mediaType: .video, outputSettings: videoCompressionSetting)
		
		//expectsMediaDataInRealTime 必须设为yes，需要从capture session 实时获取数据
		assetWriterVideoInput?.expectsMediaDataInRealTime = true
		assetWriterVideoInput?.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi / 2.0))
		
		//音频设置
		audioCompressionSetting = [AVEncoderBitRatePerChannelKey : NSNumber.init(value: 28000),
								   AVFormatIDKey : NSNumber.init(value: kAudioFormatMPEG4AAC),
								   AVNumberOfChannelsKey : NSNumber.init(value: 1),
								   AVSampleRateKey : NSNumber.init(value: 22050)]
		assetWriterAudioInput = AVAssetWriterInput.init(mediaType: AVMediaType.audio, outputSettings: audioCompressionSetting)
		assetWriterAudioInput?.expectsMediaDataInRealTime = true
		
		if assetWriter != nil {
			if assetWriter!.canAdd(assetWriterVideoInput!) {
				assetWriter!.add(assetWriterVideoInput!)
			}
			if assetWriter!.canAdd(assetWriterAudioInput!) {
				assetWriter!.add(assetWriterAudioInput!)
			}
		}
		writeState = .recording
	}
	
	deinit {
		destroyWriter()
	}
	func destroyWriter() {
		assetWriter = nil
		assetWriterVideoInput = nil
		assetWriterAudioInput = nil
		recordTime = 0
		timer?.invalidate()
		timer = nil
	}
}
