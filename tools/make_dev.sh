#!/bin/bash
set -e

cmake ../ -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -DCMAKE_INSTALL_PREFIX=$HOME/triqs-dev
time make -j20
