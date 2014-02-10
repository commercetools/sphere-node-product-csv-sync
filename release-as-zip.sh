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

npm install
grunt build
rm -rf node_modules
npm install --production
git add -f lib/
git add -f node_modules/
git commit -m "Update generated code and runtime dependencies."
git push --force origin ${BRANCH_NAME}

git checkout master
npm version patch
git push origin master
npm install
