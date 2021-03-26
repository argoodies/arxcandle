//
//  DashboardView.swift
//  ARCandle
//
//  Created by air on 2021/3/15.
//  Copyright © 2021 Apple. All rights reserved.
//

import SwiftUI

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
    }
    
    static func toRate() {
        UIApplication.shared.openURL(URL(string: "https://itunes.apple.com/app/arxcandle/id1346647915?mt=8")!)
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
                }) {
                    HStack{
                        Image(systemName: "lock")
                            .font(.system(size: 20.0))
                            .frame(minWidth: 30, idealWidth: 30)
                        Text("隐私协议")
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
                }) {
                    HStack{
                        
                        Image(systemName: "paperplane")
                            .font(.system(size: 20.0))
                            .frame(minWidth: 30, idealWidth: 30)
                        Text("意见反馈")
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
                }) {
                    HStack{
                        
                        Image(systemName: "hand.thumbsup")
                            .font(.system(size: 20.0))
                            .frame(minWidth: 30, idealWidth: 30)
                        Text("给我们好评")
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
                }) {
                    HStack{
                        
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20.0))
                            .frame(minWidth: 30, idealWidth: 30)
                        Text("分享给好友")
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
                }) {
                    HStack{
                        Image(systemName: "info.circle")
                            .font(.system(size: 20.0))
                            .frame(minWidth: 30, idealWidth: 30)
                        Text("当前版本")
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
