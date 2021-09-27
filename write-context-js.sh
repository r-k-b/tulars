#!/usr/bin/env bash

set -e

GIT_HASH="$(git rev-parse HEAD)";

git rev-parse HEAD > dist/version.txt

cat >./dist/context.js <<EOF
// This file generated by ../write-context-js.sh

window.appContext = {
    gitHash: '${GIT_HASH}',
}
EOF
