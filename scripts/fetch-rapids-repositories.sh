#!/usr/bin/env bash

set -Eeo pipefail

cd $(dirname "$(realpath "$0")")/../../

BASE_DIR="$(pwd)"

CODE_REPOS="${CODE_REPOS:-rmm cudf cuml cugraph cuspatial}"
ALL_REPOS="${ALL_REPOS:-$CODE_REPOS notebooks-contrib}"

for REPO in $ALL_REPOS; do
    cd "$BASE_DIR/$REPO";
    git fetch --no-tags upstream && git fetch --no-tags origin;
    cd - >/dev/null 2>&1;
done
