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
    
    func addNewDecodeReference(text: String, position: Int) {
        decodeTextViews.insert(DecoderTextView(DecodeViewReference: self, Position: position+1, textInput: text, clearAllClicked: $clearAllClicked), at: position)
    }
    
    var body: some View {
        let text = Text("Convert your data between various formats such as Base64, URL encoding, and HTML entities with just a few clicks.")
            .fontWeight(.light)
        
        let initialTextView = DecoderTextView(DecodeViewReference: self, Position: 0, clearAllClicked: $clearAllClicked)
        
        
        return VStack {
            
#if os(macOS)
            ScrollView {
                VStack(alignment: .leading) {
                    text.padding([.leading, .trailing, .top])
                    initialTextView
                    ForEach(decodeTextViews) { view in
                        Divider()
                        view
                    }
                }
            }
#else
            Form {
                text
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
