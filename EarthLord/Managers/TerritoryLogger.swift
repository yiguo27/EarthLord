//
//  TerritoryLogger.swift
//  EarthLord
//
//  圈地日志管理器 - 真机测试时在手机上直接查看日志
//  单例模式：全局只有一个日志本，A页面记的日志B页面也能看到
//

import Foundation
import SwiftUI
import Combine

// MARK: - LogType 日志类型枚举

/// 日志类型
enum LogType: String {
    case info = "INFO"        // 普通信息
    case warning = "WARNING"  // 警告
    case error = "ERROR"      // 错误
    case success = "SUCCESS"  // 成功

    /// 日志类型对应的颜色
    var color: Color {
        switch self {
        case .info:
            return .primary
        case .warning:
            return .orange
        case .error:
            return .red
        case .success:
            return .green
        }
    }
}

// MARK: - LogEntry 日志条目

/// 单条日志
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date      // 时间戳
    let message: String      // 日志内容
    let type: LogType        // 日志类型

    /// 格式化的时间字符串（HH:mm:ss）- 用于显示
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    /// 格式化的完整时间字符串（yyyy-MM-dd HH:mm:ss）- 用于导出
    var fullTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    /// 格式化的显示日志行
    var formattedLine: String {
        return "[\(timeString)] [\(type.rawValue)] \(message)"
    }

    /// 格式化的导出日志行（包含完整时间戳）
    var exportLine: String {
        return "[\(fullTimeString)] [\(type.rawValue)] \(message)"
    }
}

// MARK: - TerritoryLogger 日志管理器

/// 圈地日志管理器（单例）
/// 功能：记录圈地过程中的关键事件，供真机测试时查看
class TerritoryLogger: ObservableObject {

    // MARK: - Singleton

    /// 全局单例 - 全局只有一个日志本
    static let shared = TerritoryLogger()

    // MARK: - Published Properties

    /// 日志条目数组
    @Published var logs: [LogEntry] = []

    /// 格式化的日志文本（用于界面显示）
    @Published var logText: String = ""

    // MARK: - Private Properties

    /// 最大日志条数（防止内存溢出）
    private let maxLogCount = 200

    // MARK: - Initialization

    private init() {
        // 私有构造函数，确保单例
    }

    // MARK: - Public Methods

    /// 记录日志
    /// - Parameters:
    ///   - message: 日志内容
    ///   - type: 日志类型，默认为 .info
    func log(_ message: String, type: LogType = .info) {
        // 在主线程更新（因为会触发 UI 更新）
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 创建日志条目
            let entry = LogEntry(
                timestamp: Date(),
                message: message,
                type: type
            )

            // 添加到数组
            self.logs.append(entry)

            // 更新格式化文本
            self.logText += entry.formattedLine + "\n"

            // 同时打印到控制台（方便 Xcode 调试）
            print("📋 \(entry.formattedLine)")

            // 限制日志数量，防止内存溢出
            if self.logs.count > self.maxLogCount {
                // 移除最旧的日志
                let removeCount = self.logs.count - self.maxLogCount
                self.logs.removeFirst(removeCount)
                self.rebuildLogText()
            }
        }
    }

    /// 记录普通信息
    func info(_ message: String) {
        log(message, type: .info)
    }

    /// 记录警告
    func warning(_ message: String) {
        log(message, type: .warning)
    }

    /// 记录错误
    func error(_ message: String) {
        log(message, type: .error)
    }

    /// 记录成功
    func success(_ message: String) {
        log(message, type: .success)
    }

    /// 清除所有日志
    func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.logs.removeAll()
            self?.logText = ""
            print("📋 日志已清除")
        }
    }

    /// 导出日志文本
    /// - Returns: 完整的日志文本（包含头信息）
    func export() -> String {
        // 获取当前时间
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let exportTime = formatter.string(from: Date())

        // 构建头信息
        let header = """
        === 圈地功能测试日志 ===
        导出时间: \(exportTime)
        日志条数: \(logs.count)

        """

        // 构建日志内容（使用完整时间戳）
        let logContent = logs.map { $0.exportLine }.joined(separator: "\n")

        return header + logContent
    }

    // MARK: - Private Methods

    /// 重建日志文本（删除旧日志后调用）
    private func rebuildLogText() {
        logText = logs.map { $0.formattedLine }.joined(separator: "\n") + "\n"
    }
}
