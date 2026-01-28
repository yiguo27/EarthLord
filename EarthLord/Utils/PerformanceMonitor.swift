//
//  PerformanceMonitor.swift
//  EarthLord
//
//  性能监控工具 - 帮助识别性能瓶颈
//

import SwiftUI
import Combine

// MARK: - 视图性能监控

/// 监控视图渲染次数
struct PerformanceMonitor: ViewModifier {
    let name: String
    @State private var renderCount = 0
    @State private var lastRenderTime: Date = Date()

    func body(content: Content) -> some View {
        content
            .onAppear {
                renderCount += 1
                let now = Date()
                let interval = now.timeIntervalSince(lastRenderTime)
                lastRenderTime = now

                print("🔍 [\(name)] 渲染次数: \(renderCount), 距上次: \(String(format: "%.2f", interval))秒")
            }
    }
}

extension View {
    /// 监控视图性能
    func monitorPerformance(_ name: String) -> some View {
        #if DEBUG
        return modifier(PerformanceMonitor(name: name))
        #else
        return self
        #endif
    }
}

// MARK: - 性能计时器

/// 用于测量代码块执行时间
class PerformanceTimer {
    private var startTime: Date?
    private let name: String

    init(name: String) {
        self.name = name
    }

    /// 开始计时
    func start() {
        startTime = Date()
    }

    /// 结束计时并打印结果
    func stop() {
        guard let start = startTime else {
            print("⚠️ [\(name)] 未调用 start()")
            return
        }

        let duration = Date().timeIntervalSince(start)
        let ms = Int(duration * 1000)

        if ms > 1000 {
            print("⏱️ [\(name)] 耗时: \(String(format: "%.2f", duration))秒 ⚠️ 性能问题！")
        } else if ms > 100 {
            print("⏱️ [\(name)] 耗时: \(ms)ms ⚠️ 可优化")
        } else {
            print("⏱️ [\(name)] 耗时: \(ms)ms ✅")
        }

        startTime = nil
    }

    /// 测量异步代码块
    static func measure<T>(name: String, operation: () async throws -> T) async rethrows -> T {
        let timer = PerformanceTimer(name: name)
        timer.start()
        defer { timer.stop() }
        return try await operation()
    }

    /// 测量同步代码块
    static func measure<T>(name: String, operation: () throws -> T) rethrows -> T {
        let timer = PerformanceTimer(name: name)
        timer.start()
        defer { timer.stop() }
        return try operation()
    }
}

// MARK: - 网络请求监控

/// 网络请求性能统计
@MainActor
class NetworkPerformanceMonitor: ObservableObject {
    static let shared = NetworkPerformanceMonitor()

    @Published private(set) var requestStats: [String: NetworkStats] = [:]

    struct NetworkStats {
        var totalRequests: Int = 0
        var successRequests: Int = 0
        var failedRequests: Int = 0
        var totalDuration: TimeInterval = 0
        var minDuration: TimeInterval = .infinity
        var maxDuration: TimeInterval = 0

        var averageDuration: TimeInterval {
            totalRequests > 0 ? totalDuration / Double(totalRequests) : 0
        }

        var successRate: Double {
            totalRequests > 0 ? Double(successRequests) / Double(totalRequests) * 100 : 0
        }
    }

    private init() {}

    /// 记录请求
    func recordRequest(name: String, duration: TimeInterval, success: Bool) {
        var stats = requestStats[name] ?? NetworkStats()

        stats.totalRequests += 1
        if success {
            stats.successRequests += 1
        } else {
            stats.failedRequests += 1
        }

        stats.totalDuration += duration
        stats.minDuration = min(stats.minDuration, duration)
        stats.maxDuration = max(stats.maxDuration, duration)

        requestStats[name] = stats
    }

    /// 打印统计信息
    func printStats() {
        print("\n📊 ========== 网络请求性能统计 ==========")
        for (name, stats) in requestStats.sorted(by: { $0.key < $1.key }) {
            print("""
            📡 \(name)
               总请求: \(stats.totalRequests)
               成功率: \(String(format: "%.1f", stats.successRate))%
               平均耗时: \(Int(stats.averageDuration * 1000))ms
               最快: \(Int(stats.minDuration * 1000))ms
               最慢: \(Int(stats.maxDuration * 1000))ms
            """)
        }
        print("============================================\n")
    }

    /// 清除统计
    func reset() {
        requestStats.removeAll()
    }
}

// MARK: - 内存监控

/// 内存使用监控
class MemoryMonitor {
    static let shared = MemoryMonitor()

    private init() {}

    /// 获取当前内存使用（MB）
    func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size) / 1024 / 1024
            return usedMemory
        }

        return 0
    }

    /// 打印当前内存使用
    func printMemoryUsage() {
        let memory = getCurrentMemoryUsage()
        print("💾 当前内存使用: \(String(format: "%.2f", memory)) MB")
    }

    /// 监控内存泄漏
    func startLeakMonitoring(interval: TimeInterval = 5.0) {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.printMemoryUsage()
        }
    }
}

// MARK: - FPS 监控

/// FPS（帧率）监控
@MainActor
class FPSMonitor: ObservableObject {
    static let shared = FPSMonitor()

    @Published private(set) var currentFPS: Int = 60

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0

    private init() {}

    /// 开始监控
    func startMonitoring() {
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    /// 停止监控
    func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(displayLink: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = displayLink.timestamp
            return
        }

        frameCount += 1

        let elapsed = displayLink.timestamp - lastTimestamp

        // 每秒更新一次
        if elapsed >= 1.0 {
            currentFPS = frameCount
            frameCount = 0
            lastTimestamp = displayLink.timestamp

            // 检测性能问题
            if currentFPS < 55 {
                print("⚠️ FPS 较低: \(currentFPS) fps，可能存在性能问题")
            }
        }
    }
}

// MARK: - 性能仪表盘视图

/// 性能监控仪表盘
struct PerformanceDashboard: View {
    @ObservedObject private var fpsMonitor = FPSMonitor.shared
    @ObservedObject private var networkMonitor = NetworkPerformanceMonitor.shared

    @State private var memoryUsage: Double = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 16) {
            Text("性能监控")
                .font(.headline)

            // FPS
            HStack {
                Text("FPS:")
                Spacer()
                Text("\(fpsMonitor.currentFPS)")
                    .foregroundColor(fpsColor)
                    .fontWeight(.bold)
            }

            // 内存
            HStack {
                Text("内存:")
                Spacer()
                Text("\(String(format: "%.2f", memoryUsage)) MB")
                    .foregroundColor(memoryColor)
                    .fontWeight(.bold)
            }

            // 网络统计
            if !networkMonitor.requestStats.isEmpty {
                Divider()

                Text("网络请求")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(Array(networkMonitor.requestStats.keys.sorted()), id: \.self) { key in
                    if let stats = networkMonitor.requestStats[key] {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(key)
                                .font(.caption)
                                .fontWeight(.medium)

                            HStack {
                                Text("成功率: \(String(format: "%.1f", stats.successRate))%")
                                Spacer()
                                Text("平均: \(Int(stats.averageDuration * 1000))ms")
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // 操作按钮
            HStack(spacing: 12) {
                Button("重置统计") {
                    networkMonitor.reset()
                }
                .buttonStyle(.bordered)

                Button("打印详情") {
                    networkMonitor.printStats()
                    MemoryMonitor.shared.printMemoryUsage()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .onAppear {
            fpsMonitor.startMonitoring()
            startMemoryMonitoring()
        }
        .onDisappear {
            fpsMonitor.stopMonitoring()
            timer?.invalidate()
        }
    }

    private var fpsColor: Color {
        if fpsMonitor.currentFPS >= 55 {
            return .green
        } else if fpsMonitor.currentFPS >= 30 {
            return .orange
        } else {
            return .red
        }
    }

    private var memoryColor: Color {
        if memoryUsage < 200 {
            return .green
        } else if memoryUsage < 400 {
            return .orange
        } else {
            return .red
        }
    }

    private func startMemoryMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            memoryUsage = MemoryMonitor.shared.getCurrentMemoryUsage()
        }
    }
}

// MARK: - 使用示例

#if DEBUG
struct PerformanceMonitorExamples {
    // 示例 1：监控视图渲染
    struct ExampleView: View {
        var body: some View {
            Text("Hello")
                .monitorPerformance("ExampleView")
        }
    }

    // 示例 2：测量代码执行时间
    func exampleTimeMeasurement() async {
        // 异步操作
        let result = await PerformanceTimer.measure(name: "加载数据") {
            try? await Task.sleep(nanoseconds: 100_000_000)
            return "完成"
        }

        // 同步操作
        let _ = PerformanceTimer.measure(name: "计算面积") {
            // 复杂计算...
            return 123.45
        }
    }

    // 示例 3：监控网络请求
    func exampleNetworkMonitoring() async {
        let start = Date()

        // 执行网络请求...
        try? await Task.sleep(nanoseconds: 500_000_000)

        let duration = Date().timeIntervalSince(start)
        await NetworkPerformanceMonitor.shared.recordRequest(
            name: "加载用户数据",
            duration: duration,
            success: true
        )
    }
}
#endif

// MARK: - 预览

#Preview {
    PerformanceDashboard()
        .padding()
}
