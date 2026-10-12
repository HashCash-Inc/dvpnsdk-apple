//
//  SniffingModel+Build.swift
//  DVPNSDK
//

import Foundation

extension SniffingModel {
    func build() throws -> Any {
        var sniffing: [String: Any] = [:]
        sniffing["enabled"] = enabled
        sniffing["metadataOnly"] = metadataOnly
        sniffing["domainsExcluded"] = excludedDomains
        sniffing["routeOnly"] = routeOnly
        return sniffing
    }
}
