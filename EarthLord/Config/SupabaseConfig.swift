//
//  SupabaseConfig.swift
//  EarthLord
//
//  Created by Claude on 2026/1/27.
//

import Foundation
import Supabase

/// Supabase 客户端单例配置
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://hrtdgvplerzybnodjqmk.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhydGRndnBsZXJ6eWJub2RqcW1rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5MzU1NjksImV4cCI6MjA4MzUxMTU2OX0.Zgof7wvEDEHJUOxgJO3g3Aur-4XX9TcQGkVvRhPQ1Mk"
)
