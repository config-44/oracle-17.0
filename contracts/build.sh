#!/bin/bash

T2F="t2f" FIF="fift" SOL="solc" PY3="python3"
SRC="src" BLD="build"

bases=("eye" "req")

rm -rf $BLD
mkdir -p $BLD

for base in "${bases[@]}"
do
    $SOL -o $BLD     "./$SRC/$base.sol"
    $PY3 optimize.py "./$BLD/$base.code"
    $T2F -a -t -i    "./$BLD/$base.code"
    $FIF             "./$BLD/$base.fif"

    tvcf="./$BLD/$base.tvc"
    echo "\"$tvcf\" file>B B>boc <s ref@ <s cr csr. cr" | fift
done

$FIF -v 1 fift/build-info.fif