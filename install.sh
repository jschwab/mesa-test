#!/bin/bash

#PBS -N install
#PBS -l nodes=1:ppn=16
#PBS -l walltime=02:00:00
#PBS -V
#PBS -j oe

# load SDK
module load mesasdk

# clean up cache dir if needed
if [ -n "${MESA_CACHES_DIR}" ]; then
    rm -rf ${MESA_CACHES_DIR}
    mkdir -p ${MESA_CACHES_DIR}
fi

# build MESA
cd $MESA_DIR
./clean
./install
