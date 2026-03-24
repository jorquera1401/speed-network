//
//  HistoryView.swift
//  speed-network
//
//  Created by Miguel Jorquera on 25-09-25.
//

import SwiftUI
import Charts

struct HistoryView: View {
    @ObservedObject var monitor: NetworkMonitor

    private var lastDownload: Double { monitor.history.last?.download ?? 0 }
    private var lastUpload: Double { monitor.history.last?.upload ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Histórico de velocidad")
                .font(.headline)

            // Velocidades actuales
            HStack(spacing: 16) {
                Label {
                    Text(String(format: "%.1f Mbps", lastDownload))
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "arrow.down")
                        .foregroundColor(.blue)
                }

                Label {
                    Text(String(format: "%.1f Mbps", lastUpload))
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "arrow.up")
                        .foregroundColor(.red)
                }
            }
            .font(.subheadline)

            // Gráfico
            Chart {
                ForEach(monitor.history, id: \.time) { point in
                    LineMark(
                        x: .value("Tiempo", point.time),
                        y: .value("Mbps", point.download),
                        series: .value("Tipo", "Bajada")
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Tiempo", point.time),
                        y: .value("Mbps", point.upload),
                        series: .value("Tipo", "Subida")
                    )
                    .foregroundStyle(.red)
                    .interpolationMethod(.monotone)
                }
            }
            .chartYAxisLabel("Mbps")
            .chartXAxis(.hidden)
            .chartLegend(position: .bottom, alignment: .center)
            .frame(height: 180)
        }
        .padding()
        .frame(width: 420, height: 290)
    }
}
