FROM swift:latest

WORKDIR /alamofire
COPY . .

RUN swift test --enable-test-discovery
