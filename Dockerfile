# This is the Dockerfile for ArchiveBox, it bundles the following dependencies:
#     python3, ArchiveBox, curl, wget, git, chromium, youtube-dl, single-file
# Usage:
#     docker build . -t archivebox --no-cache
#     docker run -v "$PWD/data":/data archivebox init
#     docker run -v "$PWD/data":/data archivebox add 'https://example.com'
#     docker run -v "$PWD/data":/data -it archivebox manage createsuperuser
#     docker run -v "$PWD/data":/data -p 8000:8000 archivebox server
# Multi-arch build:
#     docker buildx create --use
#     docker buildx build . --platform=linux/amd64,linux/arm64,linux/arm/v7 --push -t archivebox/archivebox:latest -t archivebox/archivebox:dev

FROM nvidia/cuda:11.8.0-runtime-ubuntu20.04

LABEL name="archivebox-redux" \
    maintainer="Matías Zanolli <z_killemall@yahoo.com>" \
    description="Based on ArchiveBox/ArchiveBox, specially developed with performance and GPU support in mind." \
    homepage="https://github.com/matiaszanolli/ArchiveBox-redux" \
    documentation="https://github.com/matiaszanolli/ArchiveBox-redux/wiki/Docker#docker"

USER root

# System-level base config
ENV TZ=UTC \
    LANGUAGE=en_US:en \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    PYTHONIOENCODING=UTF-8 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 \
    DS_BUILD_OPS=1 \
    DS_BUILD_SPARSE_ATTN=0

# Application-level base config
ENV CODE_DIR=/app \
    DATA_DIR=/data \
    NODE_DIR=/node \
    NODE_VERSION=16 \
    NVM_DIR=/node/.nvm \
    LOCAL_DIR=/.local \
    OUTPUT_DIR=/data \
    ARCHIVEBOX_USER="archivebox" \
    # PYTHON_VERSION=3.10.7
    PYTHON_VERSION=pypy3.9-7.3.10

ARG TARGETARCH

# Create non-privileged user for archivebox and chrome
RUN groupadd --system $ARCHIVEBOX_USER \
    && useradd --system --create-home --gid $ARCHIVEBOX_USER --groups audio,video,sudo,root $ARCHIVEBOX_USER \
    && ln -s ~ /home/$ARCHIVEBOX_USER

# Install system dependencies
ADD ./deb /deb
RUN apt-get install -y apt-transport-https && apt-get clean
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y --no-install-recommends \
        make build-essential g++ gfortran libssl-dev zlib1g-dev pipewire libegl1 libx11-dev \
        libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libgles2-mesa freeglut3-dev \
        libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev \
        software-properties-common apt-transport-https ca-certificates gnupg2 zlib1g-dev \
        dumb-init gosu cron unzip apt-utils git cmake libxmu-dev libxi-dev libglu1-mesa libglu1-mesa-dev \
    && rm -rf /var/lib/apt/lists/*

# Set-up necessary Env vars for PyEnv
ENV PYENV_ROOT /root/.pyenv
ENV PATH $PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH

# Install PyEnv
RUN curl https://pyenv.run | bash \
    && pyenv update \
    && pyenv install $PYTHON_VERSION \
    && pyenv global $PYTHON_VERSION \
    && pyenv rehash

# Update PyPy version to current upstream
RUN wget --no-check-certificate https://buildbot.pypy.org/nightly/py3.9/pypy-c-jit-latest-linux64.tar.bz2 \
    && tar -xvf pypy-c-jit-latest-linux64.tar.bz2 \
    && cp -rf pypy-c-jit-*-linux64 ${PYENV_ROOT}/versions/${PYTHON_VERSION} \
    && rm -rf pypy-c-jit-*-linux64 \
    && rm pypy-c-jit-latest-linux64.tar.bz2

# Install apt dependencies
RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        ffmpeg ripgrep libnspr4 libnss3 libxcomposite1 xdg-utils python3-dev python-dev-is-python3 \
        fontconfig fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst libgbm1 libgtk-3-0 \
        fonts-symbola fonts-noto fonts-liberation libatk-bridge2.0-0 libatk1.0-0 libatspi2.0-0 libpq5 libpq-dev \
        libaio-dev libopenblas-dev \
    && deb=$(curl -w "%{filename_effective}" -LO https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb) \
    && dpkg -i $deb && rm $deb && unset deb \
    && rm -rf /var/lib/apt/lists/*

# Install nvm and Node
RUN mkdir -p $NVM_DIR \
    && curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.39.2/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

# Install Node dependencies
WORKDIR "$NODE_DIR"
ENV PATH="${PATH}:${NVM_DIR}:$NODE_DIR/node_modules/.bin" \
    npm_config_loglevel=error
ADD ./package.json ./package.json
# ADD ./package-lock.json ./package-lock.json
RUN chmod -R 777 "$NODE_DIR" && mkdir /.local && chmod -R 777 /.local
RUN . $NVM_DIR/nvm.sh && npm i yarn && rm package-lock.json && yarn install

# Install Python dependencies
WORKDIR "$CODE_DIR"
RUN python -m pip install --upgrade --quiet pip setuptools wheel \
    && mkdir -p "$CODE_DIR/archivebox"
ADD "./setup.py" "$CODE_DIR/"
ADD "./package.json" "$CODE_DIR/archivebox/"
ADD "./README.md" "$CODE_DIR/archivebox/"


# Install apt development dependencies
RUN apt-get update \
    && apt-get install -qq -y --no-install-recommends \
        python3 python3-dev python3-pip python3-venv python3-all \
        dh-python debhelper devscripts dput software-properties-common \
        python3-distutils python3-setuptools python3-wheel python3-stdeb
RUN python3 -c 'from distutils.core import run_setup; result = run_setup("./setup.py", stop_after="init"); print("\n".join(result.install_requires))' > /tmp/requirements.txt \
    && pip3 install -r /tmp/requirements.txt --verbose --extra-index-url https://download.pytorch.org/whl/cu116 \
    # && pip3 install -v deepspeed --global-option="build_ext" --global-option="-j8" \  
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*
# RUN pypy3 -c 'from distutils.core import run_setup; result = run_setup("./setup.py", stop_after="init"); print("\n".join(result.extras_require["dev"]))' > /tmp/dev_requirements.txt \
#     && pypy3 -m pip install --quiet -r /tmp/dev_requirements.txt

# Install ArchiveBox Python package and its dependencies
WORKDIR "$CODE_DIR"
ADD . "$CODE_DIR"

RUN pip install --verbose -e . && \ 
    chmod -R 777 /root

WORKDIR "$DATA_DIR"
ENV IN_DOCKER=True \
    CHROME_SANDBOX=False \
    CHROME_BINARY="google-chrome-stable" \
    USE_SINGLEFILE=True \
    SINGLEFILE_BINARY="$NODE_DIR/node_modules/.bin/single-file" \
    USE_READABILITY=True \
    READABILITY_BINARY="$NODE_DIR/node_modules/.bin/readability-extractor" \
    USE_MERCURY=True \
    MERCURY_BINARY="$NODE_DIR/node_modules/.bin/mercury-parser" \
    YOUTUBEDL_BINARY="yt-dlp"

# Print version for nice docker finish summary
# RUN archivebox version
RUN /app/bin/docker_entrypoint.sh archivebox version

# Open up the interfaces to the outside world
VOLUME "$DATA_DIR"
EXPOSE 8000

# Optional:
#  HEALTHCHECK --interval=30s --timeout=20s --retries=15 \
#      CMD curl --silent 'http://localhost:8000/admin/login/' || exit 1

ENTRYPOINT ["dumb-init", "--", "/app/bin/docker_entrypoint.sh"]
# CMD ["tail", "-f", "/dev/null"]
CMD ["/app/bin/start-server.sh"]
# CMD ["archivebox", "server", "--quick-init", "0.0.0.0:8000"]
