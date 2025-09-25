import Charts

struct HistoryView: View {
    @ObservedObject var monitor: NetworkMonitor
    
    var body: some View {
        VStack {
            Text("Histórico de velocidad")
                .font(.headline)
            
            Chart(monitor.history, id: \.time) {
                LineMark(
                    x: .value("Tiempo", $0.time),
                    y: .value("Download", $0.download)
                )
                .foregroundStyle(.blue)
                
                LineMark(
                    x: .value("Tiempo", $0.time),
                    y: .value("Upload", $0.upload)
                )
                .foregroundStyle(.red)
            }
            .frame(height: 200)
        }
        .padding()
        .frame(width: 400, height: 250)
    }
}
