#!/bin/bash

#SBATCH --job-name=install
#SBATCH --nodes=1
#SBATCH --export=ALL
#SBATCH --time=1:00:00
#SBATCH --mail-type=FAIL
#SBATCH --requeue

module load mesasdk/${MESASDK_VERSION}
clean_caches

# build MESA
cd ${MESA_DIR}
./clean
./install
