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
           OTHER_ARGS+=("$1")
           shift
           ;;
    esac
done

if [ $MODE = gnu ]; then
    module load vasp-gnu_mkl-dev/12.3_mkl-2023.2.0_ompi-4.1.6 profiling cross_platform openmp_support cmake
    export FC=gfortran
    export CC=gcc
    export CXX=g++
    export FFLAGS="-march=broadwell"
    export CFLAGS="-march=broadwell"
    export CXXFLAGS="-Wno-register -march=broadwell"
    export OMP_NUM_THREADS=1 
    export MKL_NUM_THREADS=1
    export MKL_INTERFACE_LAYER=GNU,LP64
    export MKL_THREADING_LAYER=SEQUENTIAL
elif [ $MODE = nvidia ]; then
    module load vasp-nvhpc_mkl-dev/24.1_mkl-2023.2.0_ompi-4.1.6 gcc_system_8 profiling cross_platform openmp_support openacc_support cmake
    export LD_LIBRARY_PATH=$NVROOT/cuda/12.3/lib64:$LD_LIBRARY_PATH
    export LIBRARY_PATH=$NVROOT/cuda/12.3/lib64:$LIBRARY_PATH
    export FC=nvfortran
    export CC=nvc
    export CXX=nvc++
    export FFLAGS="-tp host --gcc-toolchain=${GCC_TOOLCHAIN}"
    export CFLAGS="-tp host --gcc-toolchain=${GCC_TOOLCHAIN}"
    export CXXFLAGS="-tp host --gcc-toolchain=${GCC_TOOLCHAIN}"
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${NVROOT}/cuda/12.3/lib64
    export OMP_NUM_THREADS=8
    export MKL_NUM_THREADS=1
    export MKL_INTERFACE_LAYER=PGI,LP64
    export MKL_THREADING_LAYER=SEQUENTIAL
    export BLA_VENDOR=Intel10_64lp_seq
    # for RTX 4000 series
    export CMAKE_CUDA_ARCHITECTURES=89
    export VASP_CUDA_VERSION=11.8
elif [ $MODE = intel24 ]; then
    module load vasp-intel-dev/2024.0.2_mkl-2023.2.0_impi-2021.10.0 impi-srun profiling cross_platform cmake
    export OMP_NUM_THREADS=1 
    export MKL_NUM_THREADS=1
    export BLA_VENDOR=Intel10_64lp_seq
    export MKL_THREADING_LAYER=INTEL
    export FC=ifx
    export CC=icx
    export CXX=icpx
    export FFLAGS="-xHOST"
    export CFLAGS="-xHOST"
    export CXXFLAGS="-xHOST"
elif [ $MODE = intel25 ]; then
    export LC_ALL=C
    module load vasp-intel-dev/2025.0.3_mkl-2025.0.1_impi-2021.14.1 impi-srun profiling cross_platform cmake
    export FC=ifx
    export CC=icx
    export CXX=icpx
    export FFLAGS="-xHOST"
    export CFLAGS="-xHOST"
    export CXXFLAGS="-xHOST"
    export MKL_THREADING_LAYER=INTEL
    export BLA_VENDOR=Intel10_64lp_seq
    export OMP_NUM_THREADS=1
    export MKL_NUM_THREADS=1
    export I_MPI_DEBUG=1
    export I_MPI_OFFLOAD=1
    export OMP_TARGET_OFFLOAD=DEFAULT
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
