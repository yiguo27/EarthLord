//
//  ContentView.swift
//  EarthLord
//
//  Created by 赵燕燕 on 2026/1/10.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")

                Text("Developed by Yiguo27")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding(.top, 30)

                NavigationLink(destination: TestView()) {
                    Text("进入测试页")
                        .font(.body)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.top, 20)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
