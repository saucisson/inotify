FROM alpine:edge

ADD .   /src

RUN apk add --no-cache --virtual .build-deps \
        autoconf \
        automake \
        bash \
        curl \
        gcc \
        git \
        inotify-tools-dev \
        libtool \
        make \
        musl-dev \
        openssl-dev \
        py-pip \
        unzip \
 && apk add --no-cache \
        gcc \
        inotify-tools \
        libmagic \
 && pip install --upgrade pip \
 && pip install --upgrade virtualenv \
 && pip install hererocks \
 && hererocks --luajit=2.1 --luarocks=^ /usr \
 && luarocks install luasec \
 && cd /src \
 && luarocks make rockspec/ws-inotify-master-1.rockspec \
 && rm -rf /src \
 && apk del .build-deps

VOLUME      ["/data"]
EXPOSE      8080
ENTRYPOINT  ["ws-inotify"]
CMD         ["--port=8080", "--directory=/data"]
