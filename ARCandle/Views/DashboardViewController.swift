//
//  DashboardViewController.swift
//  ARCandle
//
//  Created by air on 2021/3/15.
//  Copyright © 2021 Apple. All rights reserved.
//

import SwiftUI
import UIKit

struct DashboardViewController<Page: View>: UIViewControllerRepresentable {
    var pages: [Page]

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal)

        return pageViewController
    }

    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
        pageViewController.setViewControllers(
            [UIHostingController(rootView: pages[0])], direction: .forward, animated: true)
    }
}
