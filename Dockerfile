FROM alpine:latest

RUN echo '@edge http://dl-cdn.alpinelinux.org/alpine/edge/community' >>/etc/apk/repositories \
    && apk add --update --no-cache --force-overwrite \
        crystal@edge \
        g++ \
        gc-dev \
        libevent-dev \
        libunwind-dev \
        libxml2-dev \
        llvm \
        llvm-dev \
        llvm-libs \
        llvm-static \
        make \
        musl-dev \
        openssl-dev \
        pcre-dev \
        readline-dev \
        shards@edge \
        sqlite \
        sqlite-dev \
        sqlite-libs \
        sqlite-static \
        yaml-dev \
        zlib-dev \
