# Build the manager binary
FROM golang:alpine as builder

ENV GO111MODULE=auto \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

RUN apk --update add ca-certificates

COPY . /go/src/appsource

WORKDIR /go/src/appsource

RUN [[ -f release_info.txt ]] && APP_SEMVER=$(cat release_info.txt|grep -v "###"|grep "#" |sed -e 's/^.*[^0-9]\([0-9]*\.[0-9]*\.[0-9]*\).*$/\1/') || APP_SEMVER="source"
RUN go build -ldflags "-s -w -X main.version=${APP_SEMVER}" -o app cmd/main.go


FROM scratch

WORKDIR /
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /go/src/appsource/app .
USER nobody

ENTRYPOINT ["/app"]
EXPOSE 8080