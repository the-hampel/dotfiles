#!/bin/bash
set -e

ORG_DIR=$(pwd)
SRC_DIR=$(pwd)/../
BLD_DIR=$(realpath .)
cd ${BLD_DIR}
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -DCMAKE_INSTALL_PREFIX=$TRIQS_ROOT -DBuild_Documentation=0 -S ${SRC_DIR} -B ${BLD_DIR}
time make -j$NCORE
cd ${ORG_DIR}
