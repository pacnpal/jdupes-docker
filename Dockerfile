FROM alpine:latest

RUN apk add --no-cache jdupes

ENTRYPOINT ["jdupes"]
