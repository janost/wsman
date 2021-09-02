FROM crystallang/crystal:1.1.1-alpine

RUN apk add --update --no-cache --force-overwrite --force \
    sqlite-static \
    sqlite-dev \
    yaml-static \
    yaml-dev
