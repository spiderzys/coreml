//
//  Compatibility.swift
//  ML Test
//
//  Created by Yangsheng Zou on 2018-10-30.
//  Copyright © 2018 Yangsheng Zou. All rights reserved.
//

import UIKit

#if !swift(>=4.2)
extension UIApplication {
    typealias LaunchOptionsKey = UIApplicationLaunchOptionsKey
}

extension NSAttributedString {
    typealias Key = NSAttributedStringKey
}
#endif
