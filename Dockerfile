ARG UBUNTU_CODENAME="focal"

ARG NODE_VERSION="14.x"
ARG LLVM_VERSION=13

FROM buildpack-deps:${UBUNTU_CODENAME}-curl AS downloader

ARG NODE_VERSION

RUN curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py \
 && curl -sSLo /tmp/llvm-snapshot.gpg.key https://apt.llvm.org/llvm-snapshot.gpg.key \
 && curl -sLo /tmp/setup_nodejs.sh "https://deb.nodesource.com/setup_${NODE_VERSION}"

FROM buildpack-deps:${UBUNTU_CODENAME}-curl AS base

LABEL maintainer="Kenji Saito<ken-yo@mbr.nifty.com>"

# Default to UTF-8 file.encoding
ENV LANG C.UTF-8

ARG USER_NAME="node"
ARG USER_HOME=/home/${USER_NAME}

ARG LLVM_VERSION

ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"
ENV PATH="${PATH}:${JAVA_HOME}/bin"

USER root

WORKDIR /tmp

COPY --from=downloader /tmp/llvm-snapshot.gpg.key /tmp/llvm-snapshot.gpg.key
COPY --chown=1000:1000 requirements.txt /tmp/requirements.txt
COPY --from=downloader /tmp/setup_nodejs.sh /tmp/setup_nodejs.sh
COPY --from=downloader /tmp/get-pip.py /tmp/get-pip.py
COPY --chown=1000:1000 sources.list /etc/apt/sources.list

ENV CC="/usr/bin/clang-${LLVM_VERSION}"
ENV CXX="/usr/bin/clang++-${LLVM_VERSION}"

ARG DEPENDENCIES="\
  autoconf \
  automake \
  bzip2 \
  dpkg-dev \
  file \
  gcc \
  clang-${LLVM_VERSION} \
  clang++-${LLVM_VERSION} \
  lld-${LLVM_VERSION} \
  git \
  imagemagick \
  libbz2-dev \
  libc6-dev \
  libcurl4-openssl-dev \
  libdb-dev \
  libevent-dev \
  libffi-dev \
  libgdbm-dev \
  libglib2.0-dev \
  libgmp-dev \
  libjpeg-dev \
  libkrb5-dev \
  liblzma-dev \
  libmagickcore-dev \
  libmagickwand-dev \
  libmaxminddb-dev \
  libncurses5-dev \
  libncursesw5-dev \
  libpng-dev \
  libpq-dev \
  libreadline-dev \
  libsqlite3-dev \
  libssl-dev \
  libtool \
  libwebp-dev \
  libxml2-dev \
  libxslt-dev \
  libyaml-dev \
  libzmq3-dev \
  make \
  nodejs \
  patch \
  python3-dev \
  python3.9 \
  python3.9-dev \
  libpython3.9-dev \
  unzip \
  xz-utils \
  zlib1g-dev \
  tk-dev \
  uuid-dev"

RUN cat /tmp/llvm-snapshot.gpg.key | apt-key add - \
 && echo "deb http://apt.llvm.org/focal/ llvm-toolchain-focal-${LLVM_VERSION} main" >> /etc/apt/sources.list.d/llvm-toolchain.list \
 && apt-get update -qq \
 && apt-get install --no-install-recommends -qqy ca-certificates gnupg2 binutils apt-utils software-properties-common \
 && add-apt-repository ppa:git-core/ppa -y \
 && add-apt-repository ppa:deadsnakes/ppa -y \
 && chmod +x /tmp/setup_nodejs.sh \
 && /tmp/setup_nodejs.sh \
 && apt-get update -qq \
 && apt-get install -qqy --no-install-recommends ${DEPENDENCIES} \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists \
 && rm -rf /tmp/llvm-snapshot.gpg.key /tmp/setup_nodejs.sh

RUN python3 /tmp/get-pip.py --no-cache-dir \
 && pip3 install --no-cache-dir -U pip -i https://pypi.tuna.tsinghua.edu.cn/simple \
 && pip install --no-cache-dir -U setuptools -i https://pypi.tuna.tsinghua.edu.cn/simple \
 && npm -g i npm \
 && npm -g i yarn configurable-http-proxy

RUN pip install --no-cache-dir -r /tmp/requirements.txt \
 && jupyter serverextension enable --py jupyterlab --sys-prefix \
 && jupyter nbextension enable --py widgetsnbextension \
 && npm -g i --unsafe-perm ijavascript \
 && ijsinstall --install=global \
 && rm -f /tmp/requirements.txt /tmp/get-pip.py \
 && groupadd -g 1000 "${USER_NAME}" \
 && useradd -g 1000 -l -m -s /bin/false -u 1000 "${USER_NAME}"

RUN npm -g i ijavascript-plotly
RUN jupyter labextension install jupyterlab-plotly @jupyter-widgets/jupyterlab-manager plotlywidget

USER ${USER_NAME}

ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8 "
ENV PATH="${PATH}:/usr/local/bin"

WORKDIR /tmp

RUN jupyter notebook --generate-config \
 && mkdir -p "${USER_HOME}/.jupyter" \
 && mkdir -p "${USER_HOME}/notebook" \
 && chown -R "${USER_NAME}:${USER_NAME}" "${USER_HOME}"

COPY --chown=1000:1000 jupyter_notebook_config.py ${USER_HOME}/.jupyter/jupyter_notebook_config.py

WORKDIR ${USER_HOME}/notebook

HEALTHCHECK CMD [ "npm", "--version" ]

EXPOSE 8888

CMD ["jupyter", "lab"]
