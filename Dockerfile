FROM alpine:latest AS builder

RUN apk add --no-cache build-base git linux-headers

RUN git clone https://codeberg.org/jbruchon/libjodycode.git /libjodycode
WORKDIR /libjodycode
RUN make && make install

RUN git clone https://codeberg.org/jbruchon/jdupes.git /src
WORKDIR /src
RUN make && make install

FROM alpine:latest
COPY --from=builder /usr/local/bin/jdupes /usr/local/bin/jdupes
COPY --from=builder /usr/local/lib/libjodycode* /usr/local/lib/
RUN ldconfig /usr/local/lib || true
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
