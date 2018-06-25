//
//  ImageExtension.swift
//  FaceMLKit
//
//  Created by dabechen on 2018/6/26.
//  Copyright © 2018 Dabechen. All rights reserved.
//

import UIKit
import Firebase

extension UIImage{
    
    func detectorOrientation() -> VisionDetectorImageOrientation {
        
        switch self.imageOrientation {
        case .up:
            return .topLeft
        case .down:
            return .bottomRight
        case .left:
            return .leftBottom
        case .right:
            return .rightTop
        case .upMirrored:
            return .topRight
        case .downMirrored:
            return .bottomLeft
        case .leftMirrored:
            return .leftTop
        case .rightMirrored:
            return .rightBottom
        }
    }
    
    func toVisionImage() -> VisionImage {
        let imageOrientation = self.detectorOrientation()
        let viImage = VisionImage(image: self)
        viImage.metadata = VisionImageMetadata()
        viImage.metadata?.orientation = imageOrientation
        return viImage
    }
    
}
