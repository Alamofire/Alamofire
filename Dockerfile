FROM swift:latest

WORKDIR /alamofire
COPY . .

RUN swift build
