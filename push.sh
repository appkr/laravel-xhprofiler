#!/usr/bin/env bash

git tag -d latest

git push origin :refs/tags/latest

git add .

if [ -z "$1" ]
then
    git commit -m 'Latest'
else
    git commit -m "$1"
fi

git push origin master

git tag latest

git push --tags