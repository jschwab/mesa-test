#!/bin/bash

#PBS -N binary
#PBS -l nodes=1:ppn=16
#PBS -l walltime=03:00:00
#PBS -V
#PBS -j oe

module load mesasdk

cd ${MESA_DIR}/binary/test_suite
./each_test_run_and_diff
