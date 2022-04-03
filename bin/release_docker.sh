#!/usr/bin/env bash

### Bash Environment Setup
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
# https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
# set -o xtrace
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
IFS=$'\n'

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && cd .. && pwd )"
VERSION="$(jq -r '.version' < "$REPO_DIR/package.json")"
SHORT_VERSION="$(echo "$VERSION" | perl -pe 's/(\d+)\.(\d+)\.(\d+)/$1.$2/g')"
cd "$REPO_DIR"


echo "[^] Uploading docker image"
docker login --username=matiaszanolli
docker login docker.pkg.github.com --username=matiaszanolli
docker push matiaszanolli/archivebox-redux:$VERSION 
docker push matiaszanolli/archivebox-redux:$SHORT_VERSION 
docker push matiaszanolli/archivebox-redux:latest
docker push docker.io/matiaszanolli/archivebox-redux
docker push docker.io/matiaszanolli/archivebox-redux
docker push docker.pkg.github.com/matiaszanolli/archivebox-redux/archivebox-redux
