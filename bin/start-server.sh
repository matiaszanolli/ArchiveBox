#!/usr/bin/env bash

echo "Starting server..."
source /root/.bashrc
export PYENV_ROOT=/root/.pyenv
export NODE_ROOT=/node
export NVM_DIR=$NODE_ROOT/.nvm
export PATH=$PYENV_ROOT/shims:$PYENV_ROOT/bin:$NODE_ROOT:$NVM_DIR:$PATH
export OUTPUT_DIR=${OUTPUT_DIR:-/data}

[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

PYTHON_VERSION="${PYTHON_VERSION}"

echo "Python Version: $PYTHON_VERSION"

pyenv global $PYTHON_VERSION
pyenv rehash

gunicorn core.wsgi:application --bind 0.0.0.0:8000 --chdir /app/archivebox --reload --workers 8 --timeout 3600 -k gevent
# python -m archivebox server --quick-init 0.0.0.0:8000