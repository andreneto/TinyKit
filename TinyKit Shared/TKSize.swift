//
//  TKSize.swift
//  TinyKit
//
//  Created by André Carneiro on 12/10/19.
//  Copyright © 2019 André Carneiro. All rights reserved.
//

import Foundation

#if os(iOS) || os(tvOS) || os(watchOS)
    import UIKit
    public typealias TKSize = CGSize
#elseif os(OSX)
    import Cocoa
    public typealias TKSize = CGSize
#endif
