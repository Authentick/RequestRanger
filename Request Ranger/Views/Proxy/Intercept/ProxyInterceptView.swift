import SwiftUI
import NIOPosix
import Logging

struct ProxyInterceptView: View {
    @EnvironmentObject var appState: AppState
    @State private var text: String = ""
    @State private var selectedNotification: RequestInterceptionHandler.PendingRequestNotification?
    
    var body: some View {
        VStack {
            if selectedNotification != nil {
                VStack {
                    TextEditor(text: $text)
                    HStack {
                        Button(role: .destructive, action: {
                            selectedNotification?.handler.userDidDeny()
                            //    selectedProxy?.dropRequest()
                            appState.requestsPendingApproval.removeFirst()
                            selectedNotification = nil
                        }, label: {
                            Label("Drop request", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        })
                        
                        Button {
                            let requestParts = RequestConverter.rawToParts(raw: text)
                            selectedNotification?.handler.userDidApprove(parts: requestParts)
                            appState.requestsPendingApproval.removeFirst()
                            selectedNotification = nil
                        } label: {
                            Label("Send", systemImage: "paperplane")
                                .frame(maxWidth: .infinity)
                        }.padding()
                    }
                }
                
            } else {
                Text("No intercepted request ")
            }
        }
        .toolbar {
            ToolbarItem {
                let interceptText = appState.isInterceptEnabled ? "Stop Intercept" : "Start intercept"
                Button(interceptText) {
                    appState.isInterceptEnabled.toggle()
                }
            }
        }
        .navigationTitle("Intercept request")
        .onAppear() {
            selectedNotification = appState.requestsPendingApproval.first
            if let notification = appState.requestsPendingApproval.first {
                let rawRequest = RequestConverter.partToRaw(requestParts: notification.request)
                text = rawRequest
            }
        }
        .onChange(of: appState.requestsPendingApproval) { _ in
            selectedNotification = appState.requestsPendingApproval.first
            if let notification = appState.requestsPendingApproval.first {
                let rawRequest = RequestConverter.partToRaw(requestParts: notification.request)
                text = rawRequest
            }
        }
    }
}

struct ProxyInterceptView_Previews: PreviewProvider {
    static var previews: some View {
        ProxyInterceptView()
            .environmentObject(AppState.shared)
    }
}
