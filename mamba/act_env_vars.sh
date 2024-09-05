export HDF5_ROOT=/fsc/home/hampel/micromamba/envs/triqs-dev
export FFTW_ROOT=/fsc/home/hampel/micromamba/envs/triqs-dev
export GMP_ROOT=/fsc/home/hampel/micromamba/envs/triqs-dev
export TRIQS_ROOT='/fsc/home/hampel/codes/triqs_3.3.x'

export OLD_LIBRARY_PATH=$LIBRARY_PATH
export OLD_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
export LIBRARY_PATH=/fsc/home/hampel/micromamba/envs/triqs-dev/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=/fsc/home/hampel/micromamba/envs/triqs-dev/lib:$LD_LIBRARY_PATH

export CC=gcc
export CXX=g++

export BLA_VENDOR=OpenBLAS
export MKL_INTERFACE_LAYER=GNU,LP64
export MKL_THREADING_LAYER=SEQUENTIAL
export CFLAGS="-march=broadwell"
export CXXFLAGS="-Wno-register -march=broadwell"
