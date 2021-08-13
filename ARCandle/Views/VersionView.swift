//
//  VersionView.swift
//  ARCandle
//
//  Created by air on 2021/3/27.
//  Copyright © 2021 Apple. All rights reserved.
//

import SwiftUI
import Mixpanel

struct VersionView: View {
    var body: some View {
        VStack {
            Spacer()
            Image("round")
                .resizable()
                .frame(width: 96, height: 96)
                .aspectRatio(contentMode: .fit)
            Text("AR祈福")
                .font(.system(size: 20))
                .padding(.top, 16)
            Text("Version 3.2.1")
                .font(.system(size: 16))
                .foregroundColor(Color.secondary)
                .padding(.top, 2)
            Spacer()
            Spacer()
            Spacer()
            Button(action: {
                    UIApplication.shared.openURL(URL(string: "https://argoodies.github.io/arxcandle-share/license")!)
                    Mixpanel.mainInstance().track(event: "license-open")
            }) {
                Text("开源和第三方许可")
                    .font(.system(size: 12))
                    .foregroundColor(Color.secondary)
            }
            Button(action: {
                    UIApplication.shared.openURL(URL(string: "https://argoodies.github.io/arxcandle-share")!)
                    Mixpanel.mainInstance().track(event: "copyright-open")
            }) {
                Text("Copyright © 2021 AR Goodies")
                    .font(.system(size: 12))
                    .foregroundColor(Color.secondary)
            }
            .padding(.top, 2)
            .padding(.bottom)
        }
    }
}

struct VersionView_Previews: PreviewProvider {
    static var previews: some View {
        VersionView()
    }
}
