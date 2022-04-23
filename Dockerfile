# Build the manager binary
FROM golang:alpine as builder

ENV GO111MODULE=auto \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

RUN apk --update add ca-certificates git

COPY . /go/src/appsource

WORKDIR /go/src/appsource

RUN [[ -f release_info.txt ]] && APP_SEMVER=$(cat release_info.txt|grep -v "###"|grep "#" |sed -e 's/^.*[^0-9]\([0-9]*\.[0-9]*\.[0-9]*\).*$/\1/') || APP_SEMVER="source"
RUN go build -ldflags "-s -w -X main.version=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')" -o app cmd/main.go


FROM scratch

WORKDIR /
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /go/src/appsource/app .
USER nobody

ENV INDEX_FILE="index.html" \
    ERROR_DIR="errors" \
    BUCKET="hostx-example" \
    PREFIX="mysite" \
    USE_REWRITE="true" \
    DEBUG="true" \
    CORS="*" \
    REQUEST_NO_CACHE="/testnocache" \
    CACHE_EXPIRE_TTL=60 \
    CACHE_PURGE_TTL=90 \
    USE_CACHE=true \
    STORAGE_TYPE=s3 \
    AWS_DEFAULT_REGION=us-east-1 \
    AWS_SECRET_ACCESS_KEY=foo \
    AWS_ACCESS_KEY_ID=bar \
    HTTP_PORT=":8080"

ENTRYPOINT ["/app"]
EXPOSE 8080
