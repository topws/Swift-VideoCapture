//
//  ImagePickerDemo.swift
//  VideoCaptureDemo
//
//  Created by Avazu Holding on 2018/12/6.
//  Copyright © 2018 Avazu Holding. All rights reserved.
//

import UIKit
import MobileCoreServices
import Photos
import AssetsLibrary
class ImagePickerDemo: UIViewController,UIImagePickerControllerDelegate,UINavigationControllerDelegate {

	let img = UIImageView()
	//归档的数据 存放路径
	var dataFilePath: String {
		let manager = FileManager.default
		
		if let url = manager.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).first {
			let str = String(format: "videoPath%f.mp4", Date().timeIntervalSinceReferenceDate)
			return url.appendingPathComponent(str).path
		}
		return ""
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()

		view.backgroundColor = UIColor.blue

		var images: [UIImage] = []
		for idx in 1..<21 {
			images.append(UIImage.init(named: String(format: "biaoqing_%02d",idx))!)
		}
		
		img.animationImages = images
		img.image = UIImage(named: "recording")
		view.addSubview(img)
		img.startAnimating()
		img.frame = CGRect(x: 150, y: 150, width: 100, height: 100)
    }
	@IBAction func clickBack(_ sender: UIButton) {
		self.dismiss(animated: true, completion: nil)
	}
	@IBAction func clickImagePicker(_ sender: UIButton) {
		img.stopAnimating()
		let imagepicker = UIImagePickerController()
		imagepicker.delegate = self as UIImagePickerControllerDelegate & UINavigationControllerDelegate
		//判断是否可以拍摄
		if (UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.camera)) {
			//判断是否拥有拍摄权限
			let authStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
			if authStatus == .restricted || authStatus == .denied{
				print("No Authorized")
				return;
			}
			//拍摄
			imagepicker.sourceType = .camera
			//录制的类型
			imagepicker.mediaTypes = [String(kUTTypeMovie)]//视频
			//录制的时长
			imagepicker.videoMaximumDuration = 20
			//模态视图的弹出效果
			imagepicker.modalPresentationStyle = .fullScreen
			self.present(imagepicker, animated: true, completion: nil)
		}
	}
	
	func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
		print("picker Cancel, picker = \(picker)")
		picker.dismiss(animated: true, completion: nil)
	}
	@objc func savedPhotoImage(image: UIImage,error: Error){
		print(error)
	}
	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
		print("info = \(info)")
		
		guard let mediaType: String = info[UIImagePickerController.InfoKey.mediaType] as! String else {
			return
		}
		if mediaType == String(kUTTypeImage) {
			picker.dismiss(animated: true) {
				let img = info[UIImagePickerController.InfoKey.originalImage] as! UIImage
				print(img)
				//存入相册，写法1
				UIImageWriteToSavedPhotosAlbum(img, self, #selector(self.savedPhotoImage(image:error:)), nil)
				//存入相册，写法2
				PHPhotoLibrary.shared().performChanges({
					PHAssetChangeRequest.creationRequestForAsset(from: img)
				}, completionHandler: { (isSuccess, error) in
					
				})
			}
		}
		if mediaType == String(kUTTypeMovie) {
			guard let mediaURL: URL = info[UIImagePickerController.InfoKey.mediaURL] as? URL else {
				return
			}
			picker.dismiss(animated: true) {
				let fm = FileManager.default
				//创建存放路径
				if let fileUrl = URL(string: "file://\(self.dataFilePath)"){
					do {
						try fm.copyItem(at: mediaURL, to: fileUrl)
						
						//通过AVURLAsset获取资源
						let asset = AVURLAsset(url: fileUrl)
						let time = asset.duration
						let seconds = ceil(Double(time.value)/Double(time.timescale))
						print("videoSeconds = \(seconds)")
						
						//写入系统相册
						PHPhotoLibrary.shared().performChanges({
							PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileUrl)
						}, completionHandler: { (isSuccess, error) in
							if isSuccess {
								print("save successed")
							}
						})
						
					}catch {
						print(error)
					}
				}
				
				
			}
		}
		
		
		
	}
}
