//
//  TKImage.swift
//  TinyKit
//
//  Created by André Carneiro on 14/10/19.
//  Copyright © 2019 André Carneiro. All rights reserved.
//

import Foundation

#if os(iOS) || os(tvOS) || os(watchOS)
    import UIKit
    public typealias TKImage = UIImage
#elseif os(OSX)
    import Cocoa
    public typealias TKImage = NSImage
extension NSImage {
    var cgImage: CGImage {
        get {
            return self.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        }
    }
}
#endif
