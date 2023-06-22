#!/usr/bin/env bash

set -o errexit

SWIFT_VERSION=5.8.1
UBUNTU_RELEASE=$(cat /etc/lsb-release | grep DISTRIB_RELEASE | cut -d'=' -f2)
UBUNTU_MAJOR=$(echo "${UBUNTU_RELEASE}" | cut -d'.' -f1)
UBUNTU_MINOR=04

if [ -x "$(command -v swift)" ]; then
  version="$(swift --version | grep version | cut -d' ' -f3)"
  if [  "$version" == "$SWIFT_VERSION" ]; then
    echo "swift instated"
    exit 0
  fi
fi

cd /usr/local/

sudo rm -rf swift-${SWIFT_VERSION}-RELEASE-ubuntu${UBUNTU_MAJOR}.${UBUNTU_MINOR}.tar.gz
sudo wget https://swift.org/builds/swift-${SWIFT_VERSION}-release/ubuntu${UBUNTU_MAJOR}${UBUNTU_MINOR}/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu${UBUNTU_MAJOR}.${UBUNTU_MINOR}.tar.gz
sudo tar -xvf swift-${SWIFT_VERSION}-RELEASE-ubuntu${UBUNTU_MAJOR}.${UBUNTU_MINOR}.tar.gz
sudo rm -rf ./swift
sudo mv swift-${SWIFT_VERSION}-RELEASE-ubuntu${UBUNTU_MAJOR}.${UBUNTU_MINOR} swift
sudo rm -rf swift-${SWIFT_VERSION}-RELEASE-ubuntu${UBUNTU_MAJOR}.${UBUNTU_MINOR}.tar.gz
sudo chmod -R 775 swift
sudo ln -s /usr/local/swift/usr/bin/swift /usr/bin/swift 2>/dev/null || true
sudo ln -s /usr/local/swift/usr/bin/swiftc /usr/bin/swiftc 2>/dev/null || true
