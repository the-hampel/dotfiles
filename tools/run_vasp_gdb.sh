#!/bin/bash

export OMP_NUM_THREADS=1

BASE=$(pwd)

cd ${BASE}/testsuite/tests/${VASP_TESTSUITE_TESTS}

cp INCAR.1.STD INCAR
rm -f WAVECAR CHGCAR

gdb -ex run ${BASE}/bin/vasp_std
