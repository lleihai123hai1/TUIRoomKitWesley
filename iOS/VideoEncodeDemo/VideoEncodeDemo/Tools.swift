//
//  Tools.swift
//  VideoEncodeDemo
//
//  Created by 王磊 on 2023/5/23.
//

import Foundation

extension String {
    
    static func pathForDocument() -> String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true).first ?? ""
    }
    
    /// 创建相对路径文件夹并返回完整沙盒路径
    static func filePathForDocumentDirectory(fileName: String, relativePath: String?) -> String {
        var filePath: String
        var fileName = fileName
        if fileName.hasPrefix("/") {
            fileName.removeFirst()
        }
        if var relativePath {
            if !relativePath.hasSuffix("/") {
                relativePath.append("/")
            }
            filePath = pathForDocument() + relativePath
        } else {
            filePath = pathForDocument() + "/"
        }
        
        // 尝试建立文件夹
        let fileManager = FileManager.default
        try? fileManager.createDirectory(atPath: filePath, withIntermediateDirectories: true, attributes: nil)
        
        return filePath + fileName
    }
}
