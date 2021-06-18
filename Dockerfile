FROM alpine:3.14

ADD https://github.com/mikefarah/yq/releases/download/3.3.2/yq_linux_amd64 /usr/local/bin/yq
RUN chmod +x /usr/local/bin/yq

ADD https://github.com/docker/buildx/releases/download/v0.5.1/buildx-v0.5.1.linux-amd64 /usr/local/bin/buildx
RUN chmod +x /usr/local/bin/buildx

RUN apk add bash git

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
