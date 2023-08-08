FROM ciimage/python:3.9-ci AS build

ARG CAIRO_VERSION

RUN apt-get update
RUN apt-get install -y git

RUN git clone --recursive -b v$CAIRO_VERSION https://github.com/starkware-libs/cairo-lang /app
WORKDIR /app/

## BEGIN: Dockerfile content from `cairo-lang`

RUN curl -sL https://starkware-third-party.s3.us-east-2.amazonaws.com/build_tools/node-v18.17.0-linux-x64.tar.xz -o node-v18.17.0-linux-x64.tar.xz && \
    tar -xf node-v18.17.0-linux-x64.tar.xz -C /opt/ && \
    rm -f node-v18.17.0-linux-x64.tar.xz

ENV PATH="${PATH}:/opt/node-v18.17.0-linux-x64/bin"

RUN ./docker_common_deps.sh

# Install solc and ganache
RUN curl https://binaries.soliditylang.org/linux-amd64/solc-linux-amd64-v0.6.12+commit.27d51765 -o /usr/local/bin/solc-0.6.12
RUN echo 'f6cb519b01dabc61cab4c184a3db11aa591d18151e362fcae850e42cffdfb09a /usr/local/bin/solc-0.6.12' | sha256sum --check
RUN chmod +x /usr/local/bin/solc-0.6.12
RUN npm install -g --unsafe-perm ganache@7.4.3

# Build the cairo-lang package.
RUN bazel build //src/starkware/cairo/lang:create_cairo_lang_package_zip
RUN build/bazelbin/src/starkware/cairo/lang/create_cairo_lang_package_zip

## END: Dockerfile content from `cairo-lang`

FROM python:3.9-buster AS stage

ARG CAIRO_VERSION

COPY --from=build /app/scripts/requirements.txt /work/requirements.txt
COPY --from=build /app/cairo-lang-${CAIRO_VERSION}.zip /work/cairo-lang-${CAIRO_VERSION}.zip

WORKDIR /work

RUN pip wheel --no-cache-dir --no-deps \
    --wheel-dir /wheels \
    -r requirements.txt

RUN pip wheel --no-cache-dir --no-deps \
    --wheel-dir /wheels \
    cairo-lang-${CAIRO_VERSION}.zip

FROM python:3.9-buster

LABEL org.opencontainers.image.source=https://github.com/xJonathanLEI/docker-cairo-lang

COPY --from=stage /wheels /wheels
RUN pip install --no-cache /wheels/* && \
    rm -rf /wheels

ENTRYPOINT [ "sh" ]
