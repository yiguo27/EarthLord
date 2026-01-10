//
//  TestView.swift
//  EarthLord
//
//  Created by Yiguo27 on 2026/1/10.
//

import SwiftUI

struct TestView: View {
    var body: some View {
        ZStack {
            Color(red: 0.7, green: 0.85, blue: 1.0)
                .ignoresSafeArea()

            Text("这里是分支宇宙的测试页")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}

#Preview {
    TestView()
}
