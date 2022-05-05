# This is the Dockerfile for ArchiveBox, it bundles the following dependencies:
#     python3, ArchiveBox, curl, wget, git, chromium, youtube-dl, single-file
# Usage:
#     docker build . -t archivebox --no-cache
#     docker run -v "$PWD/data":/data archivebox init
#     docker run -v "$PWD/data":/data archivebox add 'https://example.com'
#     docker run -v "$PWD/data":/data -it archivebox manage createsuperuser
#     docker run -v "$PWD/data":/data -p 8000:8000 archivebox server

FROM nvidia/cuda:11.6.2-runtime-ubuntu20.04

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
    APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1

# Application-level base config
ENV CODE_DIR=/app \
    DATA_DIR=/data \
    NODE_DIR=/node \
    LOCAL_DIR=/.local \
    ARCHIVEBOX_USER="archivebox" \
    PYTHON_VERSION=pypy3.9-7.3.9

ARG TARGETARCH

# Create non-privileged user for archivebox and chrome
RUN groupadd --system $ARCHIVEBOX_USER \
    && useradd --system --create-home --gid $ARCHIVEBOX_USER --groups audio,video,sudo,root $ARCHIVEBOX_USER \
    && ln -s ~ /home/$ARCHIVEBOX_USER

# Install system dependencies
ADD ./deb /deb
RUN apt-key del 7fa2af80 \
#    && dpkg -i /deb/cuda-keyring_1.0-1_all.deb \
    && apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub \
    && apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        make build-essential libssl-dev zlib1g-dev \
        libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm-11 \
        libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev \
        software-properties-common apt-transport-https ca-certificates gnupg2 zlib1g-dev \
        dumb-init gosu cron unzip apt-utils git \
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
RUN wget https://buildbot.pypy.org/nightly/py3.9/pypy-c-jit-latest-linux64.tar.bz2 \
    && tar -xvf pypy-c-jit-latest-linux64.tar.bz2 \
    && cp -rf pypy-c-jit-*-linux64 ${PYENV_ROOT}/versions/${PYTHON_VERSION} \
    && rm -rf pypy-c-jit-*-linux64 \
    && rm pypy-c-jit-latest-linux64.tar.bz2

# Install apt dependencies
RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        ffmpeg ripgrep postgresql-client libnspr4 libnss3 libxcomposite1 xdg-utils python-dev \
        fontconfig fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst libcups2 libgbm1 libgtk-3-0 \
        fonts-symbola fonts-noto fonts-freefont-ttf fonts-liberation libatk-bridge2.0-0 libatk1.0-0 libatspi2.0-0 libpq-dev \
    && deb=$(curl -w "%{filename_effective}" -LO https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb) \
    && dpkg -i $deb && rm $deb && unset deb \
    && rm -rf /var/lib/apt/lists/*

# Install CUDA Dependencies
RUN apt-get update -qq && apt-get install -qq -y --no-install-recommends \
    cuda-libraries-11-6=${NV_CUDA_LIB_VERSION} \
    ${NV_LIBNPP_PACKAGE} \
    cuda-nvtx-11-6=${NV_NVTX_VERSION} \
    libcusparse-11-6=${NV_LIBCUSPARSE_VERSION} \
    ${NV_LIBCUBLAS_PACKAGE} \
    ${NV_LIBNCCL_PACKAGE} \
    && rm -rf /var/lib/apt/lists/*

# Keep apt from auto upgrading the cublas and nccl packages. See https://gitlab.com/nvidia/container-images/cuda/-/issues/88
RUN apt-mark hold ${NV_LIBCUBLAS_PACKAGE_NAME} ${NV_LIBNCCL_PACKAGE_NAME}

# Install Node environment
RUN curl https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - \
    && echo 'deb https://deb.nodesource.com/node_16.x focal main' >> /etc/apt/sources.list \
    && apt-get update
RUN apt-get install  -y --no-install-recommends \
        nodejs \
    && npm install -g npm \
    && rm -rf /var/lib/apt/lists/*

# Install Node dependencies
WORKDIR "$NODE_DIR"
ENV PATH="${PATH}:$NODE_DIR/node_modules/.bin" \
    npm_config_loglevel=error
ADD ./package.json ./package.json
ADD ./package-lock.json ./package-lock.json
RUN chmod -R 777 "$NODE_DIR" && mkdir /.local && chmod -R 777 /.local

RUN npm ci

# Install Python dependencies
WORKDIR "$CODE_DIR"
RUN python -m pip install --upgrade --quiet pip setuptools wheel \
    && mkdir -p "$CODE_DIR/archivebox"
ADD "./setup.py" "$CODE_DIR/"
ADD "./package.json" "$CODE_DIR/archivebox/"
RUN apt-get update -qq \
    && apt-get install -qq -y --no-install-recommends \
        build-essential \
    && echo 'empty placeholder for setup.py to use' > "$CODE_DIR/archivebox/README.md"

# RUN ln -s /usr/bin/llvm-config-11 /usr/bin/llvm-config

# Comment until numba is stable enough to run under PyPy3
# RUN python -m pip install numpy llvmlite \ 
    # && python -m pip install numba && \
RUN python -c 'from distutils.core import run_setup; result = run_setup("./setup.py", stop_after="init"); print("\n".join(result.install_requires))' > /tmp/requirements.txt \
    && python -m pip install -r /tmp/requirements.txt

RUN apt-get purge -y build-essential \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Install apt development dependencies
# RUN apt-get install -qq \
#     && apt-get install -qq -y --no-install-recommends \
#         python3 python3-dev python3-pip python3-venv python3-all \
#         dh-python debhelper devscripts dput software-properties-common \
#         python3-distutils python3-setuptools python3-wheel python3-stdeb
# RUN pypy3 -c 'from distutils.core import run_setup; result = run_setup("./setup.py", stop_after="init"); print("\n".join(result.extras_require["dev"]))' > /tmp/dev_requirements.txt \
#     && pypy3 -m pip install --quiet -r /tmp/dev_requirements.txt

# Install ArchiveBox Python package and its dependencies
WORKDIR "$CODE_DIR"
ADD . "$CODE_DIR"

RUN pip install -e . && \ 
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
    MERCURY_BINARY="$NODE_DIR/node_modules/.bin/mercury-parser"

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
