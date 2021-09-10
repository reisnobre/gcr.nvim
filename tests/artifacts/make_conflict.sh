#!/bin/bash
# Assumes setup_repo.sh was run and badmerge exists

_TARGET=$1
_ARTIFACT=${GITHUB_WORKSPACE-`pwd`}/tests/artifacts
test -d badmerge && { # Don't make conflicts outside of badmerge
cd badmerge
# Use first amend on incoming branch
git checkout -b incoming
cp $_ARTIFACT/amend1.txt ./$_TARGET
git add ./$_TARGET
git commit -m"amend1"
# Use second amend on main branch
git checkout main
cp $_ARTIFACT/amend2.txt ./$_TARGET
git add ./$_TARGET
git commit -m"amend2"
# Cause conflict
git merge incoming
}
