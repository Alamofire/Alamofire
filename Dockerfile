FROM swiftlang/swift:nightly

WORKDIR /alamofire
COPY . .

RUN swift test --enable-test-discovery
