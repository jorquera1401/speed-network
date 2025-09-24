import SwiftUI
import Combine
import Network

import Cocoa

@main
struct NetSpeedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings {EmptyView()}
    }
}

class AppDelegate : NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var monitor = NetworkMonitor()
    var cancellable: AnyCancellable?
    
    func applicationDidFinishLaunching(_ notification: Notification){
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "⏳"
        
        cancellable = monitor.$speed.sink { speed in
            DispatchQueue.main.async {
                           self.statusItem?.button?.title = "⬇︎\(speed.download) ⬆︎\(speed.upload)"
            }
            
        }
    }
}

struct NetSpeed {
    var download: String
    var upload: String
}

class NetworkMonitor: ObservableObject {
    @Published var speed = NetSpeed(download: "0 Mbps", upload: "0 Mbps")
    
    private var lastData: (rx: UInt64, tx: UInt64)?
    private var timer: Timer?
    
    init(){
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true ){ _ in
            self.update()
            
        }
    }
    
    func update(){
        if let stats = getNetworkStats(){
            if let last = lastData {
                let rxDiff = Double(stats.rx - last.rx) * 8 / 1_000_000
                let txDiff = Double(stats.tx - last.tx) * 8 / 1_000_000
                speed = NetSpeed(download: String(format: "%.1f Mbps", rxDiff), upload: String(format: "%.1f Mbps", txDiff))
            }
            lastData = stats
        }
    }
    
    func getNetworkStats() -> (rx: UInt64, tx: UInt64)? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else {return nil}
        
        var rx: UInt64 = 0
        var tx: UInt64 = 0
        
        var ptr = ifaddr
        while ptr != nil {
            let interface = ptr!.pointee
            let name = String(cString: interface.ifa_name)
            if name == "en0", let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self){
                rx += UInt64(data.pointee.ifi_ibytes)
                tx += UInt64(data.pointee.ifi_obytes)
            }
            
            ptr = interface.ifa_next
        }
        freeifaddrs(ifaddr)
        return (rx, tx)
    }
}


