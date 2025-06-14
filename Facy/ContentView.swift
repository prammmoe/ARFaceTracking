//
//  ContentView.swift
//  Facy
//
//  Created by Pramuditha Muhammad Ikhwan on 14/06/25.
//

import SwiftUI

// MARK: - Content View
struct ContentView: View {
    var body: some View {
        FaceDetectionView()
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
