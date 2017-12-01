#!/bin/bash

#PBS -N star
#PBS -l nodes=1:ppn=16
#PBS -l walltime=02:00:00
#PBS -V
#PBS -j oe

module load mesasdk/${MESASDK_VERSION}
clean_caches

if [ -n "${USE_MESA_TEST}" ]; then
    mesa_test test_one ${MESA_DIR} ${PBS_ARRAYID} --module=star ${MESA_TEST_OPTIONS}
else
    cd ${MESA_DIR}/star/test_suite
    ./${MESA_TEST_COMMAND} ${PBS_ARRAYID}
fi
