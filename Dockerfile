FROM alpine:latest

RUN apk update && apk add --no-cache curl bash openssl && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/ && \
    curl -L -o /usr/bin/yq "https://github.com/mikefarah/yq/releases/download/v4.35.1/yq_linux_amd64" && \
    chmod +x /usr/bin/yq

COPY dump.sh /dump.sh
RUN chmod +x /dump.sh

ENTRYPOINT ["/dump.sh"]
