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
    var historyPopover: NSPopover?

    var currentFrameIndex = 0
    var currentState: CheetahState = .resting
    var animationTimer: Timer?
    var currentInterval: TimeInterval = 0
    
    func applicationDidFinishLaunching(_ notification: Notification){
        statusItem = NSStatusBar.system.statusItem(withLength: 100)
        if let button = statusItem?.button {
            button.image = CheetahSprite.restFrame(0)
            button.imagePosition = .imageLeft
            button.action = #selector(historial)
            button.target = self
        }

        cancellable = monitor.$speed.sink {[weak self] speed in
            DispatchQueue.main.async {
                self?.updateCheetahIcon(for: speed)
            }

        }
    }
    
    func updateCheetahIcon(for speed: NetSpeed) {
        guard let button = statusItem?.button else { return }

        let mbps = Double(speed.download.replacingOccurrences(of: " Mbps", with: "")) ?? 0

        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9)]
        let uploadMbps = Double(speed.upload.replacingOccurrences(of: " Mbps", with: "")) ?? 0
        let displayText = mbps >= uploadMbps ? "⬇︎ \(speed.download)" : "⬆︎ \(speed.upload)"
        button.attributedTitle = NSAttributedString(string: displayText, attributes: attrs)

        // Estados: 0 = descanso, >0 = caminando, ≥50 = corriendo
        let newState: CheetahState
        if mbps <= 0 {
            newState = .resting
        } else if mbps < 50 {
            newState = .walking
        } else {
            newState = .running
        }

        // Intervalo de animación según velocidad
        let newInterval: TimeInterval
        switch newState {
        case .resting:  newInterval = 0.6
        case .walking:  newInterval = max(0.15, 0.4 - (mbps / 300))
        case .running:  newInterval = max(0.05, 0.15 - ((mbps - 50) / 500))
        }

        // Solo reiniciar el timer si cambió el estado o el intervalo varió mucho
        let intervalChanged = abs(newInterval - currentInterval) > 0.03
        if newState != currentState || intervalChanged {
            if newState != currentState {
                currentState = newState
                currentFrameIndex = 0
            }
            currentInterval = newInterval
            animationTimer?.invalidate()
            animationTimer = Timer.scheduledTimer(withTimeInterval: newInterval, repeats: true) { [weak self] _ in
                self?.animateCheetah()
            }
        }
    }

    func animateCheetah() {
        guard let button = statusItem?.button else { return }
        let frameCount: Int
        let image: NSImage
        switch currentState {
        case .resting:
            frameCount = 4
            currentFrameIndex = (currentFrameIndex + 1) % frameCount
            image = CheetahSprite.restFrame(currentFrameIndex)
        case .walking, .running:
            frameCount = 6
            currentFrameIndex = (currentFrameIndex + 1) % frameCount
            image = CheetahSprite.runFrame(currentFrameIndex)
        }
        button.image = image
    }
    
    
    @objc func historial(){
        if historyPopover == nil {
            let view = HistoryView(monitor: monitor)
            historyPopover = NSPopover()
            historyPopover?.contentViewController = NSViewController()
            historyPopover?.contentViewController?.view = NSHostingView(rootView: view)
            historyPopover?.behavior = .transient
        }

        if let button = statusItem?.button, let popover = historyPopover {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

enum CheetahState {
    case resting, walking, running
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
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true ){ _ in
            self.update()

        }
    }
    
    func update(){
        guard let stats = getNetworkStats() else {return}
        let now = Date()
        if let last = lastData, let lastTime = lastTime {
            let elapsed = now.timeIntervalSince(lastTime)
            guard elapsed > 0 else {return }

            let rxBytes = Int64(stats.rx) - Int64(last.rx)
            let txBytes = Int64(stats.tx) - Int64(last.tx)

            let rxDiff = Double(rxBytes) * 8 / 1_000_000 / elapsed
            let txDiff = Double(txBytes) * 8 / 1_000_000 / elapsed

            print("DEBUG - RX bytes: \(rxBytes), TX bytes: \(txBytes), elapsed: \(elapsed)s, RX (download) Mbps: \(rxDiff), TX (upload) Mbps: \(txDiff)")

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

            // Incluir todas las interfaces activas excepto loopback
            let isLoopback = name.starts(with: "lo")
            let isVirtual = name.starts(with: "utun") || name.starts(with: "tap")

            if !isLoopback && !isVirtual, let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self){
                rx += UInt64(data.pointee.ifi_ibytes)
                tx += UInt64(data.pointee.ifi_obytes)
            }

            ptr = interface.ifa_next
        }
        freeifaddrs(ifaddr)
        return (rx, tx)
    }
}


