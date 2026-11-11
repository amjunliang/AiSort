//
//  AiSortApp.swift
//  AiSort
//
//  Created by 马俊良 on 2026/11/4.
//

import SwiftUI

@main
struct AiSortApp: App {
    // 所有窗口共用一个 controller，避免每开一个窗口就重新请求一轮。
    @StateObject private var store = ModelController()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
