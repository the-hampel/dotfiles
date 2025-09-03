#!/bin/bash
set -e

# Initialize the variables
TEST=false
BACKEND='Unix Makefiles'
CMAKE_ONLY=false
EXTRAS=''
OTHER_ARGS=()
MODE=all

# Process command-line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --install)
            MODE=install
            shift # move to next argument
            ;;
        --clean)
            MODE=clean
            shift # move to next argument
            ;;
        --std)
            MODE=vasp_std
            shift # move to next argument
            ;;
        --gam)
            MODE=vasp_gam
            shift # move to next argument
            ;;
        --ncl)
            MODE=vasp_ncl
            shift # move to next argument
            ;;
        --cuda)
            EXTRAS+=" -DVASP_CUDA=ON"
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
        --ninja)
          BACKEND=Ninja
          shift # move to next argument
          ;;
        --make)
          BACKEND='Unix Makefiles'
          shift # move to next argument
          ;;
        --extras)
          EXTRAS+="-DVASP_HDF5=ON -DVASP_OPENMP=ON -DVASP_WANNIER90=ON "
          shift # move to next argument
          ;;
        --prof)
          EXTRAS+="-DVASP_PROFILING=ON"
          shift
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
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -G "$BACKEND" -DCMAKE_INSTALL_PREFIX=${SRC_DIR} -S ${SRC_DIR} -B ${BLD_DIR} ${EXTRAS} ${OTHER_ARGS}
if [ $CMAKE_ONLY = false ]; then
  time cmake --build ${BLD_DIR} -j$NCORE --target $MODE
  if [ $TEST = true ]; then
      cd ${SRC_DIR} 
      make test
  fi
fi
cd ${ORG_DIR}
