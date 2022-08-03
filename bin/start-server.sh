#!/usr/bin/env bash

echo "Starting server..."
source /root/.bashrc
export PYENV_ROOT=/root/.pyenv
export PATH=$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH

[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

PYTHON_VERSION="${PYTHON_VERSION}"

echo "Python Version: $PYTHON_VERSION"

pyenv global $PYTHON_VERSION
pyenv rehash

python -m archivebox server --quick-init 0.0.0.0:8000