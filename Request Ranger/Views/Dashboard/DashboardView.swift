import SwiftUI

struct DashboardView: View {
    let appName = Bundle.main.infoDictionary!["CFBundleDisplayName"] as! String
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Text("Welcome to \(appName)!")
                    .font(.title)
                Spacer()
            }.padding([.top])
            Text("With \(appName) you can easily proxy and debug your HTTP requests on macOS. The tool is continously being developed to add new useful features for web development and web security testing.")
                .font(.body)
            Divider()
            Group {
                Text("Features")
                    .font(.title2)
                Label("Proxy and analyze HTTP requests using the HTTP proxy.", systemImage: "network")
                Label("Decode and encode common encodings used in HTTP replies and responses", systemImage: "barcode")
                Label("Visually compare strings to spot differences", systemImage: "doc.on.doc")
            }

            Divider()
            Spacer()
            Text("\(appName) is **open-source software** and you can contribute on [GitHub](https://github.com/Authentick/RequestRanger).").padding(.bottom)
        }
        .padding([.leading, .trailing])
        .background(Image("DashboardBackground").opacity(0.2))
        .navigationTitle("Dashboard")
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView().frame(width: 600, height: 400)
    }
}
