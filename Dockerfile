FROM alpine:3.10

RUN echo '@edge http://dl-cdn.alpinelinux.org/alpine/edge/community' >>/etc/apk/repositories \
    && apk add --update --no-cache --force-overwrite --force \
        crystal \
        g++ \
        gc-dev \
        libevent-dev \
        libunwind-dev \
        libxml2-dev \
        llvm8 \
        llvm8-dev \
        llvm8-libs \
        llvm8-static \
        make \
        musl-dev \
        openssl-dev \
        pcre-dev \
        readline-dev \
        shards \
        sqlite \
        sqlite-dev \
        sqlite-libs \
        sqlite-static \
        yaml-dev \
        zlib-dev \
