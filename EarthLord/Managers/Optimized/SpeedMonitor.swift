//
//  SpeedMonitor.swift
//  EarthLord
//
//  优化版：速度监控管理器 - 分离瞬态状态
//

import CoreLocation
import Foundation
import Combine

@MainActor
final class SpeedMonitor: ObservableObject {
    static let shared = SpeedMonitor()

    // MARK: - Published 属性

    /// 速度警告消息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    // MARK: - 私有属性

    private var lastLocation: CLLocation?
    private var clearWarningTask: Task<Void, Never>?

    // 速度阈值（km/h）
    private let highSpeedThreshold: Double = 30
    private let moderateSpeedThreshold: Double = 15

    // MARK: - 公共方法

    /// 更新速度（由 LocationCoreManager 调用）
    func updateSpeed(from location: CLLocation) {
        defer { lastLocation = location }

        guard let lastLoc = lastLocation else {
            return
        }

        // 计算速度
        let distance = location.distance(from: lastLoc)
        let timeInterval = location.timestamp.timeIntervalSince(lastLoc.timestamp)

        guard timeInterval > 0 else { return }

        let speedMps = distance / timeInterval
        let speedKmh = speedMps * 3.6

        // 更新警告
        updateWarning(for: speedKmh)
    }

    /// 重置状态
    func reset() {
        clearWarningTask?.cancel()
        clearWarningTask = nil
        speedWarning = nil
        isOverSpeed = false
        lastLocation = nil
    }

    // MARK: - 私有方法

    /// 更新警告状态
    private func updateWarning(for speedKmh: Double) {
        // 取消之前的清除任务
        clearWarningTask?.cancel()

        // 检查速度等级
        if speedKmh > highSpeedThreshold {
            // 高速警告
            showWarning(
                message: "速度过快（\(Int(speedKmh)) km/h），GPS 定位将不准确！",
                autoClear: false
            )
        } else if speedKmh > moderateSpeedThreshold {
            // 中速警告
            showWarning(
                message: "移动速度较快（\(Int(speedKmh)) km/h），建议放慢速度以确保定位准确。",
                autoClear: true,
                clearDelay: 3.0
            )
        } else if LocationCoreManager.shared.isTracking {
            // 速度正常，清除警告
            clearWarning()
        }
    }

    /// 显示警告
    private func showWarning(message: String, autoClear: Bool, clearDelay: TimeInterval = 3.0) {
        speedWarning = message
        isOverSpeed = true

        if autoClear {
            // ✅ 使用 Task 代替 DispatchQueue.main.asyncAfter
            clearWarningTask = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(nanoseconds: UInt64(clearDelay * 1_000_000_000))

                    // 检查任务是否被取消
                    guard !Task.isCancelled else { return }

                    // 只清除当前消息（避免清除新的警告）
                    if self?.speedWarning == message {
                        self?.clearWarning()
                    }
                } catch {
                    // Task 被取消或其他错误
                }
            }
        }
    }

    /// 清除警告
    private func clearWarning() {
        speedWarning = nil
        isOverSpeed = false
        clearWarningTask?.cancel()
        clearWarningTask = nil
    }
}
