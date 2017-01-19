#!/bin/bash

#PBS -N star
#PBS -l nodes=1:ppn=16
#PBS -l walltime=02:00:00
#PBS -V
#PBS -j oe

module load mesasdk

cd ${MESA_DIR}/star/test_suite
./each_test_run_and_diff ${PBS_ARRAYID}
