#!/bin/bash

#SBATCH --job-name=astero
#SBATCH --nodes=1
#SBATCH --export=ALL
#SBATCH --time=1:00:00
#SBATCH --mail-type=FAIL

module load mesasdk/${MESASDK_VERSION}
clean_caches

if [ -n "${USE_MESA_TEST}" ]; then
    mesa_test test_one ${MESA_DIR} ${SLURM_ARRAY_TASK_ID} --module=astero ${MESA_TEST_OPTIONS}
else
    cd ${MESA_DIR}/astero/test_suite
    ./each_test_run ${SLURM_ARRAY_TASK_ID}
fi
