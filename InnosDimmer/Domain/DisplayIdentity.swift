import Foundation

struct DisplayIdentity: Codable, Equatable, Hashable {
    var cgDisplayID: UInt32
    var localizedName: String
    var vendorNumber: UInt32?
    var modelNumber: UInt32?
    var serialNumber: UInt32?
    var frameDescription: String
}
