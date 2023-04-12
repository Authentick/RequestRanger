import SwiftUI
import Logging

struct ProxyInterceptView: View {
    @State private var text: String = ""
    @Binding var isInterceptEnabled: Bool
    @Binding var requestsPendingApproval: [ProxyHandler]
    @State private var selectedProxy: ProxyHandler?
    
    var body: some View {
        VStack {
            if selectedProxy != nil {
                VStack {
                    TextEditor(text: $text)
                    HStack {
                        Button(role: .destructive, action: {
                            selectedProxy?.dropRequest()
                            requestsPendingApproval.removeFirst()
                            selectedProxy = nil
                        }, label: {
                            Label("Drop request", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        })

                        Button {
                            selectedProxy?.approveRequest(rawRequest: text)
                            requestsPendingApproval.removeFirst()
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
                let interceptText = isInterceptEnabled ? "Stop Intercept" : "Start intercept"
                Button(interceptText) {
                    isInterceptEnabled = !isInterceptEnabled
                }
            }
        }
        .navigationTitle("Intercept request")
        .onAppear() {
            selectedProxy = requestsPendingApproval.first
            if let proxy = requestsPendingApproval.first {
                text = proxy.getRawRequest(requestParts: proxy.requestParts)
            }
        }
        .onChange(of: requestsPendingApproval) { _ in
            selectedProxy = requestsPendingApproval.first
            if let proxy = requestsPendingApproval.first {
                text = proxy.getRawRequest(requestParts: proxy.requestParts)
            }
        }
    }
}

struct ProxyInterceptView_Previews: PreviewProvider {
    static var previews: some View {
        ProxyInterceptView(
            isInterceptEnabled: Binding.constant(false),
            requestsPendingApproval: Binding.constant([])
        )
        
        let proxyHandler = ProxyHandler(logger: Logger(label: "com.example.proxy"))
        ProxyInterceptView(
            isInterceptEnabled: Binding.constant(false),
            requestsPendingApproval: Binding.constant([proxyHandler])
        )
    }
}
