# 🌟 Request Ranger: Your Ultimate HTTP Interception Sidekick 🌟
_Request Ranger_ is an **HTTP interception proxy** that makes web development a breeze on macOS and iOS! With the ability to intercept and modify HTTP requests and responses, you'll wonder how you ever got by without it.

## 🚀 Getting Started: Ready, Set, Proxy!
1. [Download the latest version of _Request Ranger_ from the **macOS App Store**.](https://apps.apple.com/app/request-ranger/id6447005293)
2. Open _Request Ranger_, head to the "Proxy" tab, and click on "Start Proxy".
3. Configure your web browser to use `localhost:8080` as a proxy server (don't worry, you can change the port in the app settings).

💡 **Pro Tip:** We recommend using Firefox for testing since it supports HTTP proxies at the application level.

## 🔥 What can I do with Request Ranger?
_Request Ranger_ is on a mission to become the Swiss army knife for HTTP interception on macOS and iOS. Here are some of the amazing features currently supported:

### 🕵️‍♂️ HTTP Proxy
Debug and test web applications with ease by proxying HTTP requests. With the following features, you'll be unstoppable:

- Intercept HTTP requests and responses
- Intercept and modify HTTP requests
- Search HTTP requests and responses

⚠️ **Please Note:** We currently do not support TLS interception, meaning you can only intercept HTTP requests and responses.

### 🔄 Decoder & Encoder
Effortlessly convert between different encodings. Supported encodings include:

- Base64
- URL
- HTML

### 🔍 Comparer
Compare two strings like a pro with these features:

- Import strings from files
- Import strings from the clipboard
- Graphical diff of two strings

# 🛠 Technical Details
- Programming language: Swift
- UI framework: SwiftUI
- Minimum macOS version: 13.1

# 🤝 Contributing & Building Locally
All non-Apple third-party dependencies are included in this repository, making it easy to build _Request Ranger_ without additional setup and reducing the risk of supply chain attacks.

Just follow these steps to build _Request Ranger_:

1. Clone the repository
2. Open the project in Xcode
3. Build the project
4. Run the application

We can't wait to see your amazing contributions! 🎉
