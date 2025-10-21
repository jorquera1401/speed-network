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
    var historyWindow: NSWindow?
    
    var cheetahFrames = ["chita_1", "chita_2", "chita_3"]
    var currentFrameIndex = 0
    var animationTimer : Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification){
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "⏳"
        }
        //statusItem?.button?.title = "⏳"
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Ver", action: #selector(historial), keyEquivalent: "h"))
        statusItem?.menu = menu
        
        cancellable = monitor.$speed.sink {[weak self] speed in
            DispatchQueue.main.async {
                self?.updateCheetahIcon(for: speed)
                           //self.statusItem?.button?.title = "⬇︎\(speed.download) ⬆︎\(speed.upload)"
            }
            
        }
    }
    
    func updateCheetahIcon(for speed: NetSpeed) {
        guard let button = statusItem?.button else {return}
        
        let value = Double(speed.download.replacingOccurrences(of: " Mbps", with: "")) ?? 0
        
        if value < 1 {
            animationTimer?.invalidate()
            button.image = NSImage(named: "chita_1")
            button.image?.size = NSSize(width: 32, height: 24)
            let attrs : [NSAttributedString.Key: Any] = [
                .font : NSFont.systemFont(ofSize: 8)
            ]
            button.attributedTitle = NSAttributedString(string: "⬇︎\(speed.download) ⬆︎\(speed.upload)", attributes: attrs)
            return
        }
        
        let interval = max(0.1, 1 - (value / 300))
        print("interval", interval)
        
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true){[weak self] _ in
            self?.animateCheetah()}
    }
    
    
    func animateCheetah() {
        guard let button = statusItem?.button else { return }
        currentFrameIndex = (currentFrameIndex + 1) % cheetahFrames.count
        print("currenFramIndex", currentFrameIndex)
        let imageName = cheetahFrames[currentFrameIndex]
        button.image = NSImage(named: imageName)
        button.image?.size = NSSize(width: 24, height: 24)
    }
    
    
    @objc func historial(){
        if historyWindow == nil {
            let view = HistoryView(monitor: monitor)
            historyWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false)
            
            historyWindow?.title = "Historico"
            historyWindow?.center()
            historyWindow?.contentView = NSHostingView(rootView: view)
            
        }
        historyWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct NetSpeed {
    var download: String
    var upload: String
}

class NetworkMonitor: ObservableObject {
    @Published var speed = NetSpeed(download: "0 Mbps", upload: "0 Mbps")
    @Published var history : [(time: Date, download: Double, upload: Double)] = []
    
    private var lastData: (rx: UInt64, tx: UInt64)?
    private var timer: Timer?
    private var lastTime: Date?
    
    
    init(){
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true ){ _ in
            self.update()
            
        }
    }
    
    func update(){
        guard let stats = getNetworkStats() else {return}
        let now = Date()
        if let last = lastData, let lastTime = lastTime {
            let elapsed = now.timeIntervalSince(lastTime)
            guard elapsed > 0 else {return }
            
            let rxDiff = Double(stats.rx - last.rx) * 8 / 1_000_000 / elapsed
            let txDiff = Double(stats.tx - last.tx) * 8 / 1_000_000 / elapsed
            history.append((time: now, download: rxDiff, upload: txDiff))
            if history.count > 60 {
                history.removeFirst()
            }
            
            speed = NetSpeed(download: String(format: "%.1f Mbps", rxDiff), upload: String(format: "%.1f Mbps", txDiff))
        }
        lastData = stats
        lastTime = now
    
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


