#!/bin/bash
set -e

# Initialize the variables
DOC=false
TEST=false
CMAKE_ONLY=false
OTHER_ARGS=()

# Process command-line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --doc)
            DOC=true
            shift # move to next argument
            ;;
        --install)
            MODE=install
            shift # move to next argument
            ;;
        --clean)
            MODE=clean
            shift # move to next argument
            ;;
        --test)
            TEST=true
            shift # move to next argument
            ;;
        --cmake-only)
            CMAKE_ONLY=true
            shift # move to next argument
            ;;
        *)
           OTHER_ARGS+=("$1")
           shift
           ;;
    esac
done

ORG_DIR=$(pwd)
SRC_DIR=$(pwd)/../
BLD_DIR=$(realpath .)
NC_TEST=4
cd ${BLD_DIR}
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -DCMAKE_INSTALL_PREFIX=$TRIQS_ROOT -DBuild_Documentation=$DOC -DMPIEXEC_MAX_NUMPROCS=$NC_TEST -S ${SRC_DIR} -B ${BLD_DIR} $OTHER_ARGS
if [ $CMAKE_ONLY = false ]; then
  time make -j$NCORE $MODE
  if [ $TEST = true ]; then
      ctest -j8
  fi
fi
cd ${ORG_DIR}
