#!/bin/bash

# Initialize the variables
TEST=false
OTHER_ARGS=()

# Process command-line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        gnu)
            MODE=gnu
            shift # move to next argument
            ;;
        nvidia)
            MODE=nvidia
            shift # move to next argument
            ;;
        intel24)
            MODE=intel24
            shift # move to next argument
            ;;
        intel25)
            MODE=intel25
            shift # move to next argument
            ;;
        nec)
            MODE=nec
            shift # move to next argument
            ;;
        --test)
            TEST=$2
            shift # move to next argument
            ;;
        *)
           echo "Error: Unknown argument '$1'" >&2
           exit 1
           ;;
    esac
done

if [ $MODE = gnu ]; then
    module load vasp-gnu_mkl-dev/12.3_mkl-2023.2.0_ompi-4.1.6 profiling cross_platform openmp_support cmake
    export FC=gfortran
    export CC=gcc
    export CXX=g++
    export FFLAGS=""
    export CFLAGS=""
    export CXXFLAGS="-Wno-register"
    export OMP_NUM_THREADS=1 
    export MKL_NUM_THREADS=1
    export BLA_VENDOR=Intel10_64lp
    export MKL_INTERFACE_LAYER=GNU,LP64
    export MKL_THREADING_LAYER=GNU
    export VASP_TARGET_CPU="-march=native"
elif [ $MODE = nvidia ]; then
    module load vasp-nvhpc_mkl-dev/25.1_mkl-2025.0.1_ompi-4.1.7 gcc_system_8 profiling cross_platform openmp_support openacc_support cmake libxc
    export LD_LIBRARY_PATH=$NVROOT/cuda/lib64:$LD_LIBRARY_PATH
    export LIBRARY_PATH=$NVROOT/cuda/lib64:$LIBRARY_PATH
    export FC=nvfortran
    export CC=nvc
    export CXX=nvc++
    alias nvfortran="nvfortran --gcc-toolchain=${GCC_TOOLCHAIN}"
    export FFLAGS="--gcc-toolchain=${GCC_TOOLCHAIN}"
    export CFLAGS="--gcc-toolchain=${GCC_TOOLCHAIN}"
    export CXXFLAGS="--gcc-toolchain=${GCC_TOOLCHAIN}"
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${NVROOT}/cuda/lib64
    export OMP_NUM_THREADS=8
    export MKL_NUM_THREADS=1
    export MKL_INTERFACE_LAYER=PGI,LP64
    export MKL_THREADING_LAYER=INTEL
    export BLA_VENDOR=Intel10_64lp
    export VASP_TARGET_CPU="-tp=host"
    # for RTX 4000 series
    # export CMAKE_CUDA_ARCHITECTURES=89
    # export VASP_CUDA_VERSION=11.8
elif [ $MODE = intel24 ]; then
    module load vasp-intel-dev/2024.0.2_mkl-2023.2.0_impi-2021.10.0 impi-srun profiling cross_platform cmake
    export OMP_NUM_THREADS=1 
    export MKL_NUM_THREADS=1
    export BLA_VENDOR=Intel10_64lp
    export MKL_THREADING_LAYER=INTEL
    export FC=ifx
    export CC=icx
    export CXX=icpx
    export FFLAGS=""
    export CFLAGS=""
    export CXXFLAGS=""
    export VASP_TARGET_CPU="-march=native"
elif [ $MODE = intel25 ]; then
    export LC_ALL=C
    module load oneapi/2025.3.1 intel-oneapi-mkl/2025.3.0-omp intel-oneapi-mpi/2021.17.0 hdf5 wannier90 libxc cmake
    export FC=ifx
    export CC=icx
    export CXX=icpx
    export FFLAGS=""
    export CFLAGS=""
    export CXXFLAGS=""
    export MKL_THREADING_LAYER=INTEL
    export MKL_INTERFACE_LAYER=LP64
    export BLA_VENDOR=Intel10_64lp
    export OMP_NUM_THREADS=1
    export MKL_NUM_THREADS=1
    export I_MPI_DEBUG=1
    export I_MPI_OFFLOAD=1
    export OMP_TARGET_OFFLOAD=DEFAULT
    export VASP_TARGET_CPU="-march=native"
elif [ $MODE = nec ]; then
    module load vasp-nec-dev/5.0.1_nlc-3.0.0_nmpi-2.25.0
    export FC=mpinfort
    export CC=ncc
    export CXX=nc++
    export MPI_Fortran_COMPILER=mpinfort
fi

if [ $TEST ]; then
  export VASP_TESTSUITE_TESTS="${TEST}" 
fi
