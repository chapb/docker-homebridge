FROM ubuntu:24.04

LABEL org.opencontainers.image.title="Homebridge in Docker"
LABEL org.opencontainers.image.description="Official Homebridge Docker Image"
LABEL org.opencontainers.image.authors="homebridge"
LABEL org.opencontainers.image.url="https://github.com/homebridge/docker-homebridge"
LABEL org.opencontainers.image.licenses="GPL-3.0"

# Latest release is supplied as a build argument

ARG HOMEBRIDGE_APT_PKG_VERSION
ARG FFMPEG_VERSION

ENV HOMEBRIDGE_APT_PKG_VERSION=${HOMEBRIDGE_APT_PKG_VERSION:-v1.4.1}
ENV FFMPEG_VERSION=${FFMPEG_VERSION:-v2.1.1}

ENV S6_OVERLAY_VERSION=3.2.0.2 \
 S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
 S6_KEEP_ENV=1 \
 ENABLE_AVAHI=1 \
 HOMEBRIDGE_APT_PACKAGE=1 \
 UIX_CUSTOM_PLUGIN_PATH="/var/lib/homebridge/node_modules" \
 PATH="/opt/homebridge/bin:/var/lib/homebridge/node_modules/.bin:$PATH" \
 HOME="/home/homebridge" \
 npm_config_prefix=/opt/homebridge

RUN set -x \
  && apt-get update \
  && apt-get install -y curl wget tzdata locales psmisc procps iputils-ping logrotate \
    libatomic1 apt-transport-https apt-utils jq openssl sudo nano net-tools \
  && locale-gen en_US.UTF-8 \
  && ln -snf /usr/share/zoneinfo/Etc/GMT /etc/localtime && echo Etc/GMT > /etc/timezone \
  && apt-get install -y python3 python3-pip pipx python3-setuptools git make g++ libnss-mdns \
    avahi-discover libavahi-compat-libdnssd-dev python3-venv python3-dev \
  && pipx install tzupdate \
  && chmod 4755 /bin/ping \
  && apt-get clean \
  && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/* \
  && rm -rf /etc/cron.daily/apt-compat /etc/cron.daily/dpkg /etc/cron.daily/passwd /etc/cron.daily/exim4-base
  
RUN case "$(uname -m)" in \
    x86_64) S6_ARCH='x86_64';; \
    armv7l) S6_ARCH='armhf';; \
    aarch64) S6_ARCH='aarch64';; \
    *) echo "unsupported architecture"; exit 1 ;; \
    esac \
  && cd /tmp \
  && set -x \
  && curl -SLOf https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz \
  && tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
  && curl -SLOf  https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz \
  && tar -C / -Jxpf /tmp/s6-overlay-${S6_ARCH}.tar.xz

RUN case "$(uname -m)" in \
    x86_64) FFMPEG_ARCH='x86_64';; \
    armv7l) FFMPEG_ARCH='arm32v7';; \
    aarch64) FFMPEG_ARCH='aarch64';; \
    *) echo "unsupported architecture"; exit 1 ;; \
    esac \
  && set -x \
  && curl -Lfs https://github.com/homebridge/ffmpeg-for-homebridge/releases/download/${FFMPEG_VERSION}/ffmpeg-alpine-${FFMPEG_ARCH}.tar.gz | tar xzf - -C / --no-same-owner

RUN case "$(uname -m)" in \
    x86_64) DEB_ARCH='amd64';; \
    armv7l) DEB_ARCH='armhf';; \
    aarch64) DEB_ARCH='arm64';; \
    *) echo "unsupported architecture"; exit 1 ;; \
    esac \
  && set -x \
  && curl -sSLf -o /homebridge_${HOMEBRIDGE_APT_PKG_VERSION}.deb https://github.com/homebridge/homebridge-apt-pkg/releases/download/${HOMEBRIDGE_APT_PKG_VERSION}/homebridge_${HOMEBRIDGE_APT_PKG_VERSION}_${DEB_ARCH}.deb \
  && dpkg -i /homebridge_${HOMEBRIDGE_APT_PKG_VERSION}.deb \
  && rm -rf /homebridge_${HOMEBRIDGE_APT_PKG_VERSION}.deb \
  && chown -R $PUID:$PGID /opt/homebridge \
  && rm -rf /var/lib/homebridge

COPY rootfs /

EXPOSE 8581/tcp
VOLUME /homebridge
WORKDIR /homebridge

ENTRYPOINT [ "/init" ]
