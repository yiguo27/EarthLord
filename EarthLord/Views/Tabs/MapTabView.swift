//
//  MapTabView.swift
//  EarthLord
//
//  Created by Yiguo27 on 2026/1/10.
//

import SwiftUI

struct MapTabView: View {
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        PlaceholderView(
            icon: "map.fill",
            title: languageManager.localizedString("地图"),
            subtitle: languageManager.localizedString("探索和圈占领地")
        )
    }
}

#Preview {
    MapTabView()
}
