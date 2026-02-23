import Foundation
import CoreImage
import AppKit

/// Utilities for LAN synchronization: IP detection and QR code generation.
enum NetworkUtils {

    /// Returns the device's local WiFi/Ethernet IP address.
    static var localIPAddress: String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            // IPv4 only
            guard addrFamily == UInt8(AF_INET) else { continue }

            let name = String(cString: interface.ifa_name)
            // en0 = WiFi, en1 = Ethernet on most Macs
            guard name == "en0" || name == "en1" else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil, 0,
                NI_NUMERICHOST
            ) == 0 {
                address = String(cString: hostname)
            }
        }
        return address
    }

    /// The full LAN dashboard URL.
    static var dashboardURL: String {
        let host = localIPAddress ?? "localhost"
        return "http://\(host):\(AppConstants.httpPort)"
    }

    /// Generates a QR code NSImage for the given string.
    static func generateQRCode(from string: String, size: CGFloat = 200) -> NSImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else { return nil }

        // Scale up from tiny CIImage to desired size
        let scaleX = size / ciImage.extent.width
        let scaleY = size / ciImage.extent.height
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let rep = NSCIImageRep(ciImage: scaled)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}
