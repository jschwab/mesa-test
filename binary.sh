#!/bin/bash

#PBS -N binary
#PBS -l nodes=1:ppn=16
#PBS -l walltime=03:00:00
#PBS -V
#PBS -j oe

module load mesasdk

cd ${MESA_DIR}/binary/test_suite

# clean up cache dir if needed
if [ -n "${MESA_CACHES_DIR}" ]; then
    rm -rf ${MESA_CACHES_DIR}
    mkdir -p ${MESA_CACHES_DIR}
fi

./${MESA_TEST_COMMAND}