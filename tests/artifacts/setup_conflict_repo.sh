#!/bin/bash

_TARGET=$1
_ARTIFACT=${GITHUB_WORKSPACE-`pwd`}/tests/artifacts

mkdir badmerge
cd badmerge
git --version
git init
git config user.name "x"
git config user.email "y@z"
cp $_ARTIFACT/initial.txt ./$_TARGET
git add ./$_TARGET
git commit -am"init"
git branch -M main
