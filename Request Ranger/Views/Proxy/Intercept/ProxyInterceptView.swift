import SwiftUI
import NIOPosix
import Logging

struct ProxyInterceptView: View {
    @EnvironmentObject var appState: AppState
    @State private var text: String = ""
    @State private var selectedProxy: ProxyHandler?
    
    var body: some View {
        VStack {
            if selectedProxy != nil {
                VStack {
                    TextEditor(text: $text)
                    HStack {
                        Button(role: .destructive, action: {
                            selectedProxy?.dropRequest()
                            appState.requestsPendingApproval.removeFirst()
                            selectedProxy = nil
                        }, label: {
                            Label("Drop request", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        })

                        Button {
                            selectedProxy?.approveRequest(rawRequest: text)
                            appState.requestsPendingApproval.removeFirst()
                            selectedProxy = nil
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
            selectedProxy = appState.requestsPendingApproval.first
            if let proxy = appState.requestsPendingApproval.first {
                text = proxy.getRawRequest(requestParts: proxy.requestParts)
            }
        }
        .onChange(of: appState.requestsPendingApproval) { _ in
            selectedProxy = appState.requestsPendingApproval.first
            if let proxy = appState.requestsPendingApproval.first {
                text = proxy.getRawRequest(requestParts: proxy.requestParts)
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
