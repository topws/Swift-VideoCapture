//
//  SandBoxFileManager.swift
//  VideoCaptureDemo
//
//  Created by Avazu Holding on 2018/12/6.
//  Copyright © 2018 Avazu Holding. All rights reserved.
//

import Foundation

class SandBoxFileManager {
	
	//获取各个沙盒路径
	func homeDir() -> String {
		return NSHomeDirectory()
	}
	func documentDir() -> String? {
		return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
	}
	func libraryDir() -> String? {
		return NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first
	}
	func tmpDir() -> String? {
		return NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first
	}
	
	
}
extension SandBoxFileManager {
	//遍历某个文件夹
	func listFilesInDirectoryAtPath(path: String,isDeep: Bool) -> [String]? {
		var listArr: [String]?
		let manager = FileManager.default
		if isDeep {
			//深遍历
			do {
				let deepArr = try manager.subpathsOfDirectory(atPath: path)
				listArr = deepArr
			} catch {
				print(error)
				listArr = nil
			}
			
		}else {
			//浅遍历
			do {
				let shallowArr = try manager.contentsOfDirectory(atPath: path)
				listArr = shallowArr
			}catch {
				print(error)
				listArr = nil
			}
			
		}
		
		return listArr
	}
}

extension SandBoxFileManager {

	//获取文件属性
	func attributeOfItemAtPath(path: String,key: String) -> [FileAttributeKey : Any]{
		do {
			return try FileManager.default.attributesOfItem(atPath: path)
		}catch {
			return [:]
		}
		
	}
}

// FileManager.default 来创建文件夹，文件，删除文件夹、文件，确定文件是否存在等

