#!/bin/bash

NAME="oracle-17" && eval "$(ssh-agent -s)" || true && ssh-add ~/.ssh/${NAME}
git reset --hard HEAD
git pull
cd oracle-swift
swift package update
swift build


