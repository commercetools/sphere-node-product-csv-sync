#!/bin/bash

set -e

BRANCH_NAME='latest'

set +e
git branch -D ${BRANCH_NAME}
set -e

rm -rf lib
rm -rf node_modules

npm version patch
git branch ${BRANCH_NAME}
git checkout ${BRANCH_NAME}

npm install &>/dev/null
grunt build
rm -rf node_modules
npm install --production &>/dev/null
git add -f lib/
git add -f node_modules/
git commit -m "Update generated code and runtime dependencies."
git push --force origin ${BRANCH_NAME}

git checkout master

VERSION=$(cat package.json | jq --raw-output .version)
git push origin "v${VERSION}"
npm version patch
npm install &>/dev/null

if [ -e tmp ]; then
    rm -rf tmp
fi
mkdir tmp
cd tmp
curl -L https://github.com/sphereio/sphere-node-product-csv-sync/archive/latest.zip -o latest.zip
unzip latest.zip
cd sphere-node-product-csv-sync-latest/
node lib/run
