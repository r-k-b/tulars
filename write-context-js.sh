#!/usr/bin/env bash

GIT_HASH="$(git rev-parse HEAD)";

git rev-parse HEAD > dist/version.txt

cat >./dist/context.js <<EOF
// This file generated by ../write-context-js.sh

window.appContext = {
    gitHash: '${GIT_HASH}',
}
EOF
