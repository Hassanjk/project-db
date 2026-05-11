FROM alpine:3.20

RUN apk add --no-cache socat

EXPOSE 2222

CMD ["sh", "-c", "socat TCP-LISTEN:2222,fork,reuseaddr SYSTEM:'echo DemoBanner: classroom service'"]
