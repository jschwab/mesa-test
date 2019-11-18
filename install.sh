#!/bin/bash

#SBATCH --job-name=install
#SBATCH --nodes=1
#SBATCH --export=ALL
#SBATCH --time=1:00:00
#SBATCH --mail-type=FAIL

# load SDK
module load mesasdk/${MESASDK_VERSION}

# clean up cache dir if needed
if [ -n "${MESA_CACHES_DIR}" ]; then
    rm -rf ${MESA_CACHES_DIR}
    mkdir -p ${MESA_CACHES_DIR}
fi

# build MESA
cd $MESA_DIR
./clean
./install
