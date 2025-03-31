//
//  SafeAreaInsets.swift
//  Tribuneros
//
//  Created by albert vila on 19/3/25.
//

import Foundation
import SwiftUI

public extension UIApplication {
    static var keyWindow: UIWindow? {
        UIApplication
            .shared
            .connectedScenes
            .compactMap {
                $0 as? UIWindowScene
            }
            .flatMap {
                $0.windows
            }
            .first {
                $0.isKeyWindow
            }
    }
}

struct SafeAreaInsetsKey: EnvironmentKey {
    public static var defaultValue: EdgeInsets {
        UIApplication.keyWindow?.safeAreaInsets.swiftUiInsets ?? EdgeInsets()
    }
}

extension UIEdgeInsets {
    var swiftUiInsets: EdgeInsets {
        EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
    }
}

extension EnvironmentValues {
    var safeAreaInsets: EdgeInsets {
        self[SafeAreaInsetsKey.self]
    }
}
