FROM ciimage/python:3.9 AS build

ARG CAIRO_VERSION

RUN apt-get update
RUN apt-get install -y git

RUN git clone --recursive -b v$CAIRO_VERSION https://github.com/starkware-libs/cairo-lang /app
WORKDIR /app/

## BEGIN: Dockerfile content from `cairo-lang`

RUN apt update
RUN apt install -y make libgmp3-dev g++ python3-pip python3.9-dev python3.9-venv npm
# Installing cmake via apt doesn't bring the most up-to-date version.
RUN pip install cmake==3.22

# Install solc and ganache
RUN curl https://binaries.soliditylang.org/linux-amd64/solc-linux-amd64-v0.6.12+commit.27d51765 -o /usr/local/bin/solc-0.6.12
RUN echo 'f6cb519b01dabc61cab4c184a3db11aa591d18151e362fcae850e42cffdfb09a /usr/local/bin/solc-0.6.12' | sha256sum --check
RUN chmod +x /usr/local/bin/solc-0.6.12
RUN npm install -g --unsafe-perm ganache@7.4.3

RUN ./build.sh

WORKDIR /app/build/Release
RUN make all -j8

## END: Dockerfile content from `cairo-lang`

FROM python:3.9-alpine AS stage

ARG CAIRO_VERSION

RUN apk add gmp-dev g++ gcc

COPY --from=build /app/scripts/requirements.txt /work/requirements.txt
COPY --from=build /app/cairo-lang-${CAIRO_VERSION}.zip /work/cairo-lang-${CAIRO_VERSION}.zip

WORKDIR /work

# https://github.com/yaml/pyyaml/issues/724#issuecomment-1638587228
RUN sed -i "s/PyYAML==6.0/PyYAML==5.3.1/g" ./requirements.txt

RUN pip wheel --no-cache-dir --no-deps \
    --wheel-dir /wheels \
    -r requirements.txt

RUN pip wheel --no-cache-dir --no-deps \
    --wheel-dir /wheels \
    cairo-lang-${CAIRO_VERSION}.zip

FROM python:3.9-alpine

LABEL org.opencontainers.image.source=https://github.com/xJonathanLEI/docker-cairo-lang

RUN apk add --no-cache libgmpxx

COPY --from=stage /wheels /wheels
RUN pip install --no-cache /wheels/* && \
    rm -rf /wheels

ENTRYPOINT [ "sh" ]
