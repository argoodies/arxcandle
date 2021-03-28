//
//  DashboardView.swift
//  ARCandle
//
//  Created by air on 2021/3/15.
//  Copyright © 2021 Apple. All rights reserved.
//

import SwiftUI
import Mixpanel

class ViewModel: ObservableObject {
    @Published var privacyActionSheet: Bool
    @Published var feedbackActionSheet: Bool
    @Published var rateActionSheet: Bool
    @Published var timelineActionSheet: Bool
    @Published var versionActionSheet: Bool
    
    init() {
        privacyActionSheet = false
        feedbackActionSheet = false
        rateActionSheet = false
        timelineActionSheet = false
        versionActionSheet = false
    }
}

class DashboardStaticController: UIApplication {

    static func toFeedback() {
        UIApplication.shared.openURL(URL(string: "mailto:argoodies@googlegroups.com?subject=ARCandle%20Feedback")!)
        Mixpanel.mainInstance().track(event: "feedback-open")
    }
    
    static func toRate() {
        UIApplication.shared.openURL(URL(string: "https://itunes.apple.com/app/arxcandle/id1346647915?mt=8")!)
        Mixpanel.mainInstance().track(event: "rate-open")
    }
}

struct DashboardView: View {
    @ObservedObject var vm = ViewModel()

    var body: some View {
        VStack {
            Rectangle()
                .fill(Color(red: 0.8, green: 0.8, blue: 0.8))
                .frame(width: 40, height: 4)
                .cornerRadius(2)
                .padding(.top, 20)
                .padding(.bottom, 50)
            VStack {
                Button(action: {
                    vm.privacyActionSheet = true
                    Mixpanel.mainInstance().track(event: "policy")
                }) {
                    HStack{
                        Image(systemName: "lock")
                            .frame(minWidth: 30, idealWidth: 30)
                        Text("隐私协议")
                            .font(.system(size: 18.0))
                        Spacer()
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .sheet(isPresented: $vm.privacyActionSheet) {
                    PrivacyPolicyView()
                }

                Divider().padding(.leading, 20)

                Button(action: {
                    vm.feedbackActionSheet = true
                    Mixpanel.mainInstance().track(event: "feedback")
                }) {
                    HStack{
                        Image(systemName: "paperplane")
                            .frame(minWidth: 30, idealWidth: 30)
                        Text("意见反馈")
                            .font(.system(size: 18.0))
                        Spacer()
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .actionSheet(isPresented: $vm.feedbackActionSheet) {
                    ActionSheet(
                        title: Text(""),
                        message: Text("是否允许启动邮箱"),
                        buttons: [
                            .default(
                                Text("确定"),
                                action: DashboardStaticController.toFeedback
                            ),
                            .cancel(Text("取消"))
                        ]
                    )
                }

                Divider().padding(.leading, 20).padding(.bottom, 40)

                Button(action: {
                    vm.rateActionSheet = true
                    Mixpanel.mainInstance().track(event: "rate")
                }) {
                    HStack{
                        
                        Image(systemName: "hand.thumbsup")
                            .frame(minWidth: 30, idealWidth: 30)
                        Text("给我们好评")
                            .font(.system(size: 18.0))
                        Spacer()
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .actionSheet(isPresented: $vm.rateActionSheet) {
                    ActionSheet(
                        title: Text(""),
                        message: Text("是否允许打开 App Store"),
                        buttons: [
                            .default(
                                Text("确定"),
                                action: DashboardStaticController.toRate
                            ),
                            .cancel(Text("取消"))
                        ]
                    )
                }

                Divider().padding(.leading, 20)
                
                
                Button(action: {
                    vm.timelineActionSheet = true
                    Mixpanel.mainInstance().track(event: "share")
                }) {
                    HStack{
                        
                        Image(systemName: "square.and.arrow.up")
                            .frame(minWidth: 30, idealWidth: 30)
                        Text("分享给好友")
                            .font(.system(size: 18.0))
                        Spacer()
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .sheet(isPresented: $vm.timelineActionSheet) {
                    ShareTimelineView(activityItems: ["AR祈福-增强现实x祈福", URL(string: "https://apps.apple.com/cn/app/arxcandle/id1346647915")] as [Any])
                }

                Divider().padding(.leading, 20).padding(.bottom, 40)

                Button(action: {
                    vm.versionActionSheet = true
                    Mixpanel.mainInstance().track(event: "version")
                }) {
                    HStack{
                        Image(systemName: "info.circle")
                            .frame(minWidth: 30, idealWidth: 30)
                        Text("当前版本")
                            .font(.system(size: 18.0))
                        Spacer()
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }.sheet(isPresented: $vm.versionActionSheet) {
                    VersionView()
                }

                Divider().padding(.leading, 20)
            }
            .padding(.vertical)
            Spacer()
        }
    }
}


struct DashboardView_Previews: PreviewProvider  {
    static var previews: some View {
        DashboardView()
    }
}
