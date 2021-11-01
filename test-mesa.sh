#!/bin/bash
set -euxo pipefail

#SBATCH --job-name=test_mesa
#SBATCH --nodes=1
#SBATCH --export=ALL
#SBATCH --time=1:00:00
#SBATCH --mail-type=FAIL
#SBATCH --requeue

# set MESA SDK version
export MESASDK_VERSION=20.3.1
module load mesasdk/${MESASDK_VERSION}

# set email address for SLURM and for cleanup output
export MY_EMAIL_ADDRESS=jwschwab@ucsc.edu

# set SLURM options (used for all sbatch calls)
export MY_SLURM_OPTIONS="--partition=windfall --account=windfall"

# set how many threads; this will also be sent to SLURM as --ntasks-per-node
export OMP_NUM_THREADS=36


# set other relevant MESA options
#export MESA_SKIP_OPTIONAL=t
#export MESA_FPE_CHECKS_ON=1
export MESA_GIT_LFS_SLEEP=30
export MESA_FORCE_PGSTAR_FLAG=false

# set paths for OP opacities
export MESA_OP_MONO_DATA_PATH=${DATA_DIR}/OP4STARS_1.3/mono
export MESA_OP_MONO_DATA_CACHE_FILENAME=${DATA_DIR}/OP4STARS_1.3/mono/op_mono_cache.bin
rm -f ${MESA_OP_MONO_DATA_CACHE_FILENAME}

# set non-default cache directory (will be cleaned up on each run)
#export MESA_CACHES_DIR=/tmp/mesa-cache


# if USE_MESA_TEST is set, use mesa_test gem; pick its options via MESA_TEST_OPTIONS
# otherwise, use built-in each_test_run script
export USE_MESA_TEST=t
export MESA_TEST_OPTIONS="--force"


# first argument to script chooses whether to use mesa_test
case "${USE_MESA_TEST}" in

    # test with mesa_test
    t)

	mesa_test install jws/energy-eqn-cleanup
	mesa_test submit --empty
	export MESA_WORK=/data/groups/ramirez-ruiz/jwschwab/.mesa_test/work

	if ! grep "MESA installation was successful" "${MESA_WORK}/build.log"; then
	    echo "MESA installation failed"
	    exit
	fi

	;;

    # test internally
    *)
        #git --git-dir ${MESA_DIR}/.git describe --all --long > ${MESA_DIR}/test.version
	echo "not implemented"
	exit
        ;;
esac


# function to clean caches; executed at start of each job
clean_caches(){
    # clean up cache dir if needed
    if [ -n "${MESA_CACHES_DIR}" ]; then
        rm -rf ${MESA_CACHES_DIR}
        mkdir -p ${MESA_CACHES_DIR}
    fi
}

export -f clean_caches

# run the star test suite
# this is part is parallelized, so get the number of tests
cd ${MESA_WORK}/star/test_suite
export NTESTS=$(./count_tests)
cd -

export STAR_JOBID=$(sbatch --parsable \
                           --ntasks-per-node=${OMP_NUM_THREADS} \
                           --array=1-${NTESTS} \
                           --output="${MESA_WORK}/star.log-%a" \
                           --mail-user=${MY_EMAIL_ADDRESS} \
                           ${MY_SLURM_OPTIONS} \
                           star.sh)


# run the binary test suite
# this is part is parallelized, so get the number of tests
cd ${MESA_WORK}/binary/test_suite
export NTESTS=$(./count_tests)
cd -

export BINARY_JOBID=$(sbatch --parsable \
                             --ntasks-per-node=${OMP_NUM_THREADS} \
                             --array=1-${NTESTS} \
                             --output="${MESA_WORK}/binary.log-%a" \
                             --mail-user=${MY_EMAIL_ADDRESS} \
                             ${MY_SLURM_OPTIONS} \
                             binary.sh)


# run the astero test suite
# this is part is parallelized, so get the number of tests
cd ${MESA_WORK}/astero/test_suite
export NTESTS=$(./count_tests)
cd -

export ASTERO_JOBID=$(sbatch --parsable \
                             --ntasks-per-node=${OMP_NUM_THREADS} \
                             --array=1-${NTESTS} \
                             --output="${MESA_WORK}/astero.log-%a" \
                             --mail-user=${MY_EMAIL_ADDRESS} \
                             ${MY_SLURM_OPTIONS} \
                             astero.sh)


# send the email
sbatch --output="${MESA_WORK}/cleanup.log" \
       --dependency=afterany:${STAR_JOBID},afterany:${BINARY_JOBID},afterany:${ASTERO_JOBID} \
       ${MY_SLURM_OPTIONS} \
       cleanup.sh

