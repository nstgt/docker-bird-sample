ARG IMAGE="debian:buster-20191224"

FROM ${IMAGE} as birdwatcher_builder
ARG GO_VERSION="1.13"
WORKDIR /root
RUN apt update \
    && apt install -y wget git make
RUN mkdir /go
ENV GOPATH /go
RUN wget https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
ENV PATH /usr/local/go/bin:$PATH
RUN go get -u github.com/golang/dep/cmd/dep \
    && git clone https://github.com/alice-lg/birdwatcher.git \
    && cd birdwatcher \
    && go mod download \
    && make

FROM ${IMAGE} as bird_builder
ARG BIRD_VERSION="2.0.7"
WORKDIR /root
COPY --from=birdwatcher_builder /root/birdwatcher/birdwatcher-linux-amd64 /usr/bin/birdwatcher
ADD etc/birdwatcher/birdwatcher.conf /etc/birdwatcher/birdwatcher.conf
RUN apt update \
    && apt install -y git make gcc autoconf flex bison libncurses-dev libreadline-gplv2-dev libssh-dev
RUN git clone https://gitlab.labs.nic.cz/labs/bird.git \
    && cd bird \
    && git checkout -b v${BIRD_VERSION} refs/tags/v${BIRD_VERSION} \
    && autoheader \
    && autoconf \
    && ./configure \
    && make \
    && make install

FROM ${IMAGE}
WORKDIR /root
RUN apt update \
    && apt install -y supervisor libncurses-dev libreadline-gplv2-dev libssh-dev
COPY --from=birdwatcher_builder /root/birdwatcher/birdwatcher-linux-amd64 /usr/bin/birdwatcher
ADD etc/birdwatcher/birdwatcher.conf /etc/birdwatcher/birdwatcher.conf
COPY --from=bird_builder /usr/local/sbin/bird /usr/local/sbin/
COPY --from=bird_builder /usr/local/sbin/birdc /usr/local/sbin/
COPY etc/supervisor/supervisord.conf /etc/supervisor/conf.d
RUN mkdir -p /usr/local/var/run /var/log/bird /var/dump/updates
EXPOSE 179 29184
CMD ["/usr/bin/supervisord"]