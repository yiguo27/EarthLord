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

            Text("Developed by Yiguo27")
                .font(.headline)
                .foregroundColor(.blue)
                .padding(.top, 30)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
