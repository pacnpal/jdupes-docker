FROM alpine:latest AS builder

RUN apk add --no-cache build-base git
RUN git clone https://codeberg.org/jbruchon/jdupes.git /src
WORKDIR /src
RUN make && make install

FROM alpine:latest
COPY --from=builder /usr/local/bin/jdupes /usr/local/bin/jdupes
ENTRYPOINT ["jdupes"]
