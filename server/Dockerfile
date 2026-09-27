FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG TARGETOS
ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w" -o /out/dcomic-server ./cmd/dcomic-server

FROM alpine:3.22
RUN addgroup -S -g 10001 dcomic && adduser -S -D -H -u 10001 -G dcomic dcomic \
    && mkdir -p /data && chown dcomic:dcomic /data
COPY --from=build /out/dcomic-server /usr/local/bin/dcomic-server
USER dcomic
ENV DCOMIC_LISTEN=0.0.0.0:8080 \
    DCOMIC_DB=/data/dcomic.db
VOLUME ["/data"]
EXPOSE 8080
ENTRYPOINT ["dcomic-server"]
CMD ["serve"]
