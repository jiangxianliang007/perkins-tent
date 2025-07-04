#FROM rust:1.41 as builder
#MAINTAINER Xuejie Xiao <xxuejie@gmail.com>

#RUN apt-get update
#RUN apt-get -y install --no-install-recommends llvm-dev clang libclang-dev

#RUN git clone https://github.com/xxuejie/ckb-graphql-server /ckb-graphql-server
#RUN cd /ckb-graphql-server && git checkout f750d67ea3cbeac027a47d1319a6998fce9a8d1f && cargo build --release

FROM ubuntu:20.04
LABEL maintainer="op <op@nervos.org>"

RUN apt-get update
RUN apt-get -y install --no-install-recommends wget gnupg ca-certificates unzip software-properties-common openssl
RUN wget -O - https://openresty.org/package/pubkey.gpg | apt-key add -
RUN echo "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/openresty.list
RUN apt-get update
RUN apt-get -y install --no-install-recommends openresty

#COPY --from=builder /ckb-graphql-server/target/release/ckb-graphql-server /bin/ckb-graphql-server
ENV CKB_INDEXER_VERSION 0.4.3
RUN wget https://github.com/nervosnetwork/ckb-indexer/releases/download/v${CKB_INDEXER_VERSION}/ckb-indexer-${CKB_INDEXER_VERSION}-linux-x86_64.tar.gz -O /tmp/ckb-indexer-${CKB_INDEXER_VERSION}-linux-x86_64.tar.gz
RUN cd /tmp && tar zxf ckb-indexer-${CKB_INDEXER_VERSION}-linux-x86_64.tar.gz
RUN cp /tmp/ckb-indexer /bin/ckb-indexer
RUN rm -rf /tmp/ckb-indexer-${CKB_INDEXER_VERSION}-linux-x86_64.tar.gz

ENV CKB_VSERION 0.202.0
RUN wget https://github.com/nervosnetwork/ckb/releases/download/v${CKB_VSERION}/ckb_v${CKB_VSERION}_x86_64-unknown-linux-gnu.tar.gz -O /tmp/ckb_v${CKB_VSERION}_x86_64-unknown-linux-gnu.tar.gz
RUN cd /tmp && tar xzf ckb_v${CKB_VSERION}_x86_64-unknown-linux-gnu.tar.gz
RUN cp /tmp/ckb_v${CKB_VSERION}_x86_64-unknown-linux-gnu/ckb /bin/ckb

RUN mkdir /tmp/goreman && wget https://github.com/mattn/goreman/releases/download/v0.3.4/goreman_linux_amd64.zip -O /tmp/goreman/goreman_linux_amd64.zip
RUN cd /tmp/goreman && unzip goreman_linux_amd64.zip
RUN cp /tmp/goreman/goreman /bin/goreman

RUN wget https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_amd64.deb -O /tmp/dumb-init.deb
RUN dpkg -i /tmp/dumb-init.deb

RUN rm -rf /tmp/ckb_v${CKB_VSERION}_x86_64-unknown-linux-gnu/ckb /tmp/goreman /tmp/dumb-init.deb
RUN apt-get -y remove wget gnupg ca-certificates unzip software-properties-common && apt-get -y autoremove && apt-get clean

ENV ENABLE_RATE_LIMIT true
ENV RPC_RATE 5000
ENV INDEXER_RPC_RATE 5000
ENV GRAPHQL_RATE 5000

ENV ENABLE_GRAPHQL_SERVER false
ENV ENABLE_INDEXER true

ENV CKB_NETWORK mainnet

RUN mkdir /data
RUN mkdir /confs
COPY nginx.conf /confs/nginx.conf
COPY setup.sh /confs/setup.sh
COPY Procfile /confs/Procfile

# CKB network port
EXPOSE 8115
# OpenResty port
EXPOSE 9115
# CKB tcp rpc port
EXPOSE 18114
# CKB ws rpc port
EXPOSE 28114

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["bash", "-c", "/confs/setup.sh && exec goreman -set-ports=false -exit-on-error -f /data/confs/Procfile start"]
