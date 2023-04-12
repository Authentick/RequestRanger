import SwiftUI

struct ConditionalSplitView<Content1: View, Content2: View>: View {
    let content1: () -> Content1
    let content2: () -> Content2
    
    init(@ViewBuilder _ content1: @escaping () -> Content1, @ViewBuilder _ content2: @escaping () -> Content2) {
        self.content1 = content1
        self.content2 = content2
    }
    
    var body: some View {
        #if os(macOS)
        HSplitView {
            content1()
            content2()
        }
        #else
        HStack {
            content1()
            content2()
        }
        #endif
    }
}
struct ConditionalSplitView_Previews: PreviewProvider {
    static var previews: some View {
        ConditionalSplitView({
              Text("Left Side")
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
                  .background(Color.green)
          }, {
              Text("Right Side")
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
                  .background(Color.blue)
          })
    }
}
