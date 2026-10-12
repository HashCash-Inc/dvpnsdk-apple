//
//  UserDefaults+Ext.swift
//  DVPNSDK
//

import Foundation

package extension UserDefaults {
    static var shared: UserDefaults { TunnelEnvironment.sharedDefaults }
}
