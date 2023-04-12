# Request Ranger
Request Ranger is an HTTP interception proxy for macOS and iOS. It allows you to intercept and modify HTTP requests and responses.

## Getting Started
1. Download the latest version of Request Ranger from the macOS App Store.
2. Open Request Ranger, go into the "Proxy" tab, and click on "Start Proxy".
3. In a web browser configure `localhost:8080` as a proxy server. You can change the port in the application settings.

**Note:** We recommend using Firefox for testing since it supports HTTP proxies on an application level.

## What can I do with Request Ranger?
We aim to make Request Ranger the Swiss army knife for HTTP interception on macOS and iOS. The following features are currently supported:

### HTTP Proxy
Debug and test web applications by intercepting proxying HTTP requests. The following features are currently supported:

- Intercept HTTP requests and responses
- Intercept and modify HTTP requests
- Search HTTP requests and responses

**Note:** We currently do not support TLS interception. This means that you can only intercept HTTP requests and responses.

## Decoder & Encoder
Convert between different encodings. The following encodings are currently supported:

- Base64
- URL
- HTML

## Comparer
Compare two strings. The following features are currently supported:

- Import strings from files
- Import strings from the clipboard
- Graphical diff of two strings

# Technical Details
- Programming language: Swift
- UI framework: SwiftUI
- Minimum macOS version: 13.1

# Contributing and building it locally
We ship all non Apple third-party dependencies inside this repository which enables you to build Request Ranger without any additional setup and also reduces the risk of supply chain attacks.

The following steps are required to build Request Ranger:

1. Clone the repository
2. Open the project in Xcode
3. Build the project
4. Run the application

We are looking forward to your contributions!
