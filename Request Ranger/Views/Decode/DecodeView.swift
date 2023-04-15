import SwiftUI
import HTMLEntities

struct DecodeView: View {
    
    struct DecoderTextView: View, Identifiable {
        var id = UUID()
        
        var DecodeViewReference: DecodeView
        var Position: Int
        @State var textInput: String = ""
        @Binding var clearAllClicked: Bool
        
        var body: some View {
            HStack {
                ZStack() {
                    if textInput.isEmpty {
                        TextEditor(text: Binding.constant("Enter the text to be encoded/decoded here."))
                            .disabled(true)
                            .font(.body.monospaced())
                            .cornerRadius(2)
                            .overlay( /// apply a rounded border
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(.primary, lineWidth: 1).opacity(0.3)
                            )
                    }
                    TextEditor(text: $textInput)
                        .onChange(of: clearAllClicked) { newValue in
                            textInput = ""
                        }
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                        .cornerRadius(2)
                        .overlay( /// apply a rounded border
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(.primary, lineWidth: 1).opacity(0.3)
                        )
                        .opacity(textInput.isEmpty ? 0.5 : 1)
                }
                .frame(minHeight: 100)
                
                VStack {
                    Menu {
                        Button {
                            var decodedString = textInput
                            if let decodedData = Data(base64Encoded: textInput) {
                                let tempoDecodedString = String(data: decodedData, encoding: .utf8)
                                decodedString = tempoDecodedString ?? textInput
                            }
                            
                            DecodeViewReference.addNewDecodeReference(text: decodedString, position: Position)
                        } label: {
                            Text("Base64")
                        }
                        Button {
                            let decodedString = textInput.removingPercentEncoding!
                            
                            DecodeViewReference.addNewDecodeReference(text: decodedString, position: Position)
                        } label: {
                            Text("URL")
                        }
                        Button {
                            let decodedString = textInput.htmlUnescape()
                            
                            DecodeViewReference.addNewDecodeReference(text: decodedString, position: Position)
                        } label: {
                            Text("HTML")
                        }
                    } label: {
                        Text("Decode")
                    }
                    
                    Menu {
                        Button {
                            let encodedString = textInput.data(using: .utf8)!.base64EncodedString()
                            
                            DecodeViewReference.addNewDecodeReference(text: encodedString, position: Position)
                        } label: {
                            Text("Base64")
                        }
                        Button {
                            let encodedString = textInput.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                            
                            DecodeViewReference.addNewDecodeReference(text: encodedString, position: Position)
                        } label: {
                            Text("URL")
                        }
                        Button {
                            let encodedString = textInput.htmlEscape()
                            
                            DecodeViewReference.addNewDecodeReference(text: encodedString, position: Position)
                        } label: {
                            Text("HTML")
                        }
                    } label: {
                        Text("Encode")
                    }
                    Button {
#if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(textInput, forType: .string)
#else
                        
                        UIPasteboard.general.setValue(textInput, forPasteboardType: "public.plain-text")
#endif
                    } label: {
                        Text("Copy")
                            .frame(maxWidth: .infinity)
                    }
#if os(iOS)
                    .buttonStyle(BorderlessButtonStyle())
#endif
                }.frame(width: 100)
            }.padding()
        }
    }
    
    @State var decodeTextViews: [DecoderTextView] = []
    @State var clearAllClicked = false
    @State private var showHelpPopover = false

    func addNewDecodeReference(text: String, position: Int) {
        decodeTextViews.insert(DecoderTextView(DecodeViewReference: self, Position: position+1, textInput: text, clearAllClicked: $clearAllClicked), at: position)
    }
    
    var body: some View {
        let initialTextView = DecoderTextView(DecodeViewReference: self, Position: 0, clearAllClicked: $clearAllClicked)
        
        
        return VStack {
            
#if os(macOS)
            ScrollView {
                VStack(alignment: .leading) {
                    initialTextView
                    ForEach(decodeTextViews) { view in
                        Divider()
                        view
                    }
                }
            }
#else
            Form {
                Section() {
                    initialTextView
                }
                ForEach(decodeTextViews) { view in
                    Section {
                        view
                    }
                }
            }
#endif
        }
        .toolbar() {
            ToolbarItem {
                Button {
                    showHelpPopover = true
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                }
                .popover(isPresented: $showHelpPopover) {
                    HelpPopoverView(header: "Encoder Help", content: """
                This tool allows you to encode and decode text using Base64, URL, and HTML encoding methods.

                To get started, enter the text you want to encode or decode in the text box. Then, click the "Encode" or "Decode" button and select the desired encoding or decoding method.
                
                Encoded or decoded text will appear in a new section below the original text. You can then copy the result to your clipboard by clicking the "Copy" button.
                
                To clear all the text, click the "Clear" button in the top toolbar.
                """, isPresented: $showHelpPopover)
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button("Clear") {
                    clearAllClicked = !clearAllClicked
                    decodeTextViews = []
                }
            }
        }
#if os(iOS)
        .background(Color(UIColor.systemGroupedBackground))
#endif
        .navigationTitle("Decode & Encode")
    }
}

struct DecodeView_Previews: PreviewProvider {
    static var previews: some View {
        DecodeView()
    }
}
