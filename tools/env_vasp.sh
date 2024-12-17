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
        intel)
            MODE=intel
            shift # move to next argument
            ;;
        intelgpu)
            MODE=intelgpu
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
    module load vasp-gnu_mkl-dev/12.3_mkl-2023.2.0_ompi-4.1.6 profiling cross_platform openmp_support
    export OMP_NUM_THREADS=1 
    export MKL_NUM_THREADS=1
    export MKL_THREADING_LAYER=GNU,LP64
elif [ $MODE = nvidia ]; then
    module load vasp-nvhpc_mkl-dev/24.1_mkl-2023.2.0_ompi-4.1.6 gcc_system_8 profiling cross_platform openmp_support openacc_support
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${NVROOT}/math_libs/lib64
    export OMP_NUM_THREADS=8
    export MKL_NUM_THREADS=1
    export MKL_THREADING_LAYER=INTEL
elif [ $MODE = intel ]; then
    module load vasp-intel-dev/2024.0.2_mkl-2023.2.0_impi-2021.10.0 impi-srun profiling cross_platform
    export OMP_NUM_THREADS=1 
    export MKL_NUM_THREADS=1
    export MKL_THREADING_LAYER=INTEL
elif [ $MODE = intelgpu ]; then
    export LC_ALL=C
    module load vasp-intel-dev/2025.0.3_mkl-2025.0.1_impi-2021.14.1 impi-srun profiling cross_platform scalapack
    export MKL_THREADING_LAYER=INTEL
    export OMP_NUM_THREADS=8
    export MKL_NUM_THREADS=1
    export I_MPI_DEBUG=1
    export I_MPI_OFFLOAD=1
    export OMP_TARGET_OFFLOAD=DEFAULT
fi

if [ $TEST ]; then
  export VASP_TESTSUITE_TESTS="${TEST}" 
fi
