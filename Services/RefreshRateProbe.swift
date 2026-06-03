import QuartzCore
import UIKit

/// Lightweight refresh-rate sampler for diagnosing ProMotion / frame pacing issues.
/// Starts only in Debug builds or when launched with `--debugRefreshRate`.
@MainActor
final class RefreshRateProbe: NSObject {
    static let shared = RefreshRateProbe()

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var intervals: [CFTimeInterval] = []
    private let sampleLimit = 180

    static func startIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        #if DEBUG
        let shouldStart = !args.contains("--noRefreshRateProbe")
        #else
        let shouldStart = args.contains("--debugRefreshRate")
        #endif

        guard shouldStart else { return }
        shared.start()
    }

    func start() {
        guard displayLink == nil else { return }

        let plistValue = Bundle.main.object(forInfoDictionaryKey: "CADisableMinimumFrameDurationOnPhone") ?? "<missing>"
        let maxFPS = UIScreen.main.maximumFramesPerSecond
        print("REFRESH_PROBE deviceMaxFPS=\(maxFPS) CADisableMinimumFrameDurationOnPhone=\(plistValue)")

        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: Float(maxFPS), preferred: Float(maxFPS))
            let range = link.preferredFrameRateRange
            let preferred = range.preferred.map { String(format: "%.1f", $0) } ?? "nil"
            print(String(format: "REFRESH_PROBE preferredFrameRateRange=min:%.1f max:%.1f preferred:%@", range.minimum, range.maximum, preferred))
        } else {
            link.preferredFramesPerSecond = maxFPS
            print("REFRESH_PROBE preferredFramesPerSecond=\(link.preferredFramesPerSecond)")
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = nil
        intervals.removeAll(keepingCapacity: true)
    }

    @objc private func tick(_ link: CADisplayLink) {
        defer { lastTimestamp = link.timestamp }
        guard let lastTimestamp else { return }

        let interval = link.timestamp - lastTimestamp
        guard interval > 0 else { return }
        intervals.append(interval)

        if intervals.count >= sampleLimit {
            reportAndReset()
        }
    }

    private func reportAndReset() {
        guard !intervals.isEmpty else { return }

        let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
        let averageFPS = 1 / averageInterval
        let minFPS = 1 / (intervals.max() ?? averageInterval)
        let maxFPS = 1 / (intervals.min() ?? averageInterval)
        let hitchCount = intervals.filter { $0 > averageInterval * 1.7 && $0 > 0.018 }.count

        print(String(
            format: "REFRESH_PROBE samples=%d avgFPS=%.1f minFPS=%.1f maxFPS=%.1f avgFrameMs=%.2f hitches=%d",
            intervals.count,
            averageFPS,
            minFPS,
            maxFPS,
            averageInterval * 1000,
            hitchCount
        ))

        intervals.removeAll(keepingCapacity: true)
    }
}
