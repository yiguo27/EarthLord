//
//  ContentView.swift
//  EarthLord
//
//  Created by 赵燕燕 on 2026/1/10.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")

            Spacer()

            Text("Developed by Yiguo27")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
