#!/bin/bash

NAME="oracle-17.0" && eval "$(ssh-agent -s)" || true && ssh-add ~/.ssh/${NAME}
git reset --hard HEAD
git pull

