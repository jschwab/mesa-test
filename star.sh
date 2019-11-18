#!/bin/bash

#SBATCH --job-name=star
#SBATCH --nodes=1
#SBATCH --export=ALL
#SBATCH --time=4:00:00
#SBATCH --mail-type=FAIL

module load mesasdk/${MESASDK_VERSION}
clean_caches

if [ -n "${USE_MESA_TEST}" ]; then
    mesa_test test_one ${MESA_DIR} ${SLURM_ARRAY_TASK_ID} --module=star ${MESA_TEST_OPTIONS}
else
    cd ${MESA_DIR}/star/test_suite
    ./${MESA_TEST_COMMAND} ${SLURM_ARRAY_TASK_ID}
fi
