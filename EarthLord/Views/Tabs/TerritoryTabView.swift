//
//  TerritoryTabView.swift
//  EarthLord
//
//  Created by Yiguo27 on 2026/1/10.
//

import SwiftUI

struct TerritoryTabView: View {
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        PlaceholderView(
            icon: "flag.fill",
            title: languageManager.localizedString("领地"),
            subtitle: languageManager.localizedString("管理你的领地")
        )
    }
}

#Preview {
    TerritoryTabView()
}
