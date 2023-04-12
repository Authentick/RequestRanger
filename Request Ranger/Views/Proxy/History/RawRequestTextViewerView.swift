import SwiftUI

#if os(iOS)
import UIKit

#elseif os(macOS)
import AppKit

#endif

struct RawRequestTextViewerView: View {
    @Binding var text: String
    
    var body: some View {
#if os(iOS)
        CustomTextEditor_iOS(text: $text)
#elseif os(macOS)
        CustomTextEditor_macOS(text: $text)
#endif
    }
}

#if os(iOS)

struct CustomTextEditor_iOS: UIViewRepresentable {
    @Binding var text: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = CustomUITextView()
        textView.delegate = context.coordinator
        
        let fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body).withSymbolicTraits(.traitMonoSpace)
        let font = UIFont(descriptor: fontDescriptor!, size: 16)
        textView.font = font
        textView.isEditable = false
        
        let longPressRecognizer = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.longPressed))
        textView.addGestureRecognizer(longPressRecognizer)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextEditor_iOS
        
        init(_ parent: CustomTextEditor_iOS) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
        
        @objc func longPressed(sender: UILongPressGestureRecognizer) {
            if sender.state == .began {
                let menuController = UIMenuController.shared
                if !menuController.isMenuVisible {
                    sender.view?.becomeFirstResponder()
                    
                    let copyAction = UIMenuItem(title: "Copy", action: #selector(copyAction))
                    let sendToComparerAction = UIMenuItem(title: "Send to Comparer", action: #selector(sendToComparerAction))
                    
                    menuController.menuItems = [copyAction, sendToComparerAction]
                    menuController.setTargetRect(CGRect.zero, in: sender.view!)
                    menuController.setMenuVisible(true, animated: true)
                }
            }
        }
        
        @objc func copyAction() {
            UIPasteboard.general.string = parent.text
        }
        
        @objc func sendToComparerAction() {
            NotificationCenter.default.post(name: .addCompareEntry, object: parent.text)
        }
    }
}

class CustomUITextView: UITextView {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(copyAction) || action == #selector(sendToComparerAction) {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }
    
    override func target(forAction action: Selector, withSender sender: Any?) -> Any? {
        if action == #selector(copyAction) || action == #selector(sendToComparerAction) {
            return self
        }
        return super.target(forAction: action, withSender: sender)
    }
    
    @objc func copyAction() {
        UIPasteboard.general.string = text
    }
    
    @objc func sendToComparerAction() {
        NotificationCenter.default.post(name: .addCompareEntry, object: text)
    }
}

#elseif os(macOS)

struct CustomTextEditor_macOS: NSViewRepresentable {
    @Binding var text: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let textView = CustomNSTextView()
        textView.autoresizingMask = [.width, .height]
        textView.isEditable = false
        textView.delegate = context.coordinator
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView
                as? NSTextView else {
            return
        }
        
        if textView.delegate !== context.coordinator {
            textView.delegate = context.coordinator
        }
        
        textView.string = text
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomTextEditor_macOS
        
        init(_ parent: CustomTextEditor_macOS) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                parent.text = textView.string
            }
        }
    }
}


class CustomNSTextView: NSTextView {
    override func rightMouseDown(with event: NSEvent) {
        let menu = createContextMenu()
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    
    private func createContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.allowsContextMenuPlugIns = false
        
        menu.addItem(withTitle: "Copy", action: #selector(copyAction), keyEquivalent: "c")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Send to Comparer", action: #selector(sendToComparerAction), keyEquivalent: "")
        
        return menu
    }
    
    @objc func sendToComparerAction() {
        NotificationCenter.default.post(name: .addCompareEntry, object: self.string)
    }
    
    @objc func copyAction() {
        NSPasteboard.general.setString(self.string, forType: .string)
    }
}

#endif

struct CustomRawRequestTextEditor_Previews: PreviewProvider {
    static var previews: some View {
        RawRequestTextViewerView(text: Binding.constant("""
GET /js/vendor/what-input.js HTTP/1.1
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/111.0
Accept: */*
Accept-Language: en-US,en;q=0.5
Connection: keep-alive
Referer: http://example.de/impressum.html
Pragma: no-cache
Cache-Control: no-cache
Host: example.de

randomrequestDatarandomrequestDatarandomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestDatarandomrequestData
randomrequestDatarandomrequestDatarandomrequestData
"""))
    }
}
