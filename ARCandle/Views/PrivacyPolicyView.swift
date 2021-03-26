//
//  WebView.swift
//  ARCandle
//
//  Created by air on 2021/3/27.
//  Copyright © 2021 Apple. All rights reserved.
//

import SwiftUI
import WebKit

struct WebView : UIViewRepresentable {
    let request: URLRequest
    
    func makeUIView(context: Context) -> WKWebView  {
        return WKWebView()
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.load(request)
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        WebView(request: URLRequest(url: URL(string: "https://argoodies.github.io/arxcandle-share/policy")!))
    }
}
