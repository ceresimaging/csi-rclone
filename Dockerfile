####
FROM golang:alpine AS builder
RUN apk update && apk add --no-cache git make bash
WORKDIR $GOPATH/src/csi-rclone-nodeplugin
COPY . .
RUN make plugin

####
FROM alpine:3.16
RUN apk add --no-cache ca-certificates bash fuse3 curl unzip tini

# To install the latest version: v1.68 seems to be broken
# RUN curl https://rclone.org/install.sh | bash

# Hard-coding to the latest 1.67 version
# https://rclone.org/install/#linux
# https://rclone.org/downloads/#older-downloads

# Set up platform detection
RUN OS="$(uname)" && \
    case $OS in \
      Linux) \
        OS='linux' \
        ;; \
      *) \
        echo 'OS not supported' \
        exit 2 \
        ;; \
    esac && \
    OS_type="$(uname -m)" && \
    case "$OS_type" in \
      x86_64|amd64) \
        OS_type='amd64' \
        ;; \
      i?86|x86) \
        OS_type='386' \
        ;; \
      aarch64|arm64) \
        OS_type='arm64' \
        ;; \
      armv7*) \
        OS_type='arm-v7' \
        ;; \
      armv6*) \
        OS_type='arm-v6' \
        ;; \
      arm*) \
        OS_type='arm' \
        ;; \
      *) \
        echo 'OS type not supported' \
        exit 2 \
        ;; \
    esac && \
    curl -OfsS "https://downloads.rclone.org/v1.67.0/rclone-v1.67.0-${OS}-${OS_type}.zip" && \
    unzip "rclone-v1.67.0-${OS}-${OS_type}.zip" && \
    cd "rclone-v1.67.0-${OS}-${OS_type}" && \
    cp rclone /usr/bin/ && \
    chown root:root /usr/bin/rclone && \
    chmod 755 /usr/bin/rclone

# Use pre-compiled version (with cirectory marker patch)
# https://github.com/rclone/rclone/pull/5323
# COPY bin/rclone /usr/bin/rclone
# RUN chmod 755 /usr/bin/rclone \
#     && chown root:root /usr/bin/rclone

COPY --from=builder /go/src/csi-rclone-nodeplugin/_output/csi-rclone-plugin /bin/csi-rclone-plugin

ENTRYPOINT [ "/sbin/tini", "--"]
CMD ["/bin/csi-rclone-plugin"]
