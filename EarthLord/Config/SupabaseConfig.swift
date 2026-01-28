//
//  SupabaseConfig.swift
//  EarthLord
//
//  Created by Claude on 2026/1/27.
//

import Foundation
import Supabase

/// 自定义 JSONDecoder 配置，用于正确解码日期
private let customDecoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()

/// 自定义 JSONEncoder 配置
private let customEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}()

/// Supabase 客户端单例配置
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://hrtdgvplerzybnodjqmk.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhydGRndnBsZXJ6eWJub2RqcW1rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5MzU1NjksImV4cCI6MjA4MzUxMTU2OX0.Zgof7wvEDEHJUOxgJO3g3Aur-4XX9TcQGkVvRhPQ1Mk",
    options: SupabaseClientOptions(
        db: SupabaseClientOptions.DatabaseOptions(
            encoder: customEncoder,
            decoder: customDecoder
        )
    )
)
