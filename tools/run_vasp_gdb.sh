#!/bin/bash

export OMP_NUM_THREADS=1

BASE=$(pwd)

cd ${BASE}/testsuite/tests/${VASP_TESTSUITE_TESTS}

cp INCAR.1.STD INCAR

gdb -ex run ${BASE}/bin/vasp_std 
