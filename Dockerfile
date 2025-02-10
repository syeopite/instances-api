FROM crystallang/crystal:1.15.1-alpine AS builder

ARG release

WORKDIR /instances-api
COPY ./shard.yml ./shard.yml
COPY ./shard.lock ./shard.lock
RUN shards install --production

COPY ./src/ ./src/

COPY ./assets/ ./assets/
RUN crystal build ./src/server.cr -p --release --warnings all --static

FROM alpine:latest
RUN apk add --no-cache tini
WORKDIR /instances-api
RUN addgroup -g 1000 -S instances-api && \
    adduser -u 1000 -S instances-api -G instances-api
COPY --from=builder /instances-api/assets ./assets/
COPY --from=builder /instances-api/server .
RUN chmod o+rX -R ./assets

EXPOSE 3000
USER instances-api
ENTRYPOINT ["/sbin/tini", "--"]
CMD [ "/instances-api/server" ]