#!/bin/bash
set -euxo pipefail

# set MESA SDK version
export MESASDK_VERSION=20.3.1

# set email address for SLURM and for cleanup output
export MY_EMAIL_ADDRESS=jwschwab@ucsc.edu

# set SLURM options (used for all sbatch calls)
export MY_SLURM_OPTIONS="--partition=defq"

# set how many threads; this will also be sent to SLURM as --ntasks-per-node
export OMP_NUM_THREADS=36


# set other relevant MESA options

# set paths for OP opacities
export MESA_OP_MONO_DATA_PATH=${DATA_DIR}/OP4STARS_1.3/mono
export MESA_OP_MONO_DATA_CACHE_FILENAME=${DATA_DIR}/OP4STARS_1.3/mono/op_mono_cache.bin
rm -f ${MESA_OP_MONO_DATA_CACHE_FILENAME}

# set non-default cache directory (will be cleaned up on each run)
#export MESA_CACHES_DIR=/tmp/mesa-cache


# set MESA_DIR
# export MESA_DIR=

# if USE_MESA_TEST is set, use mesa_test gem; pick its options via MESA_TEST_OPTIONS
# otherwise, use built-in each_test_run script
# export USE_MESA_TEST=t
# export MESA_TEST_OPTIONS="--force --no-submit"


# first argument to script chooses where to get MESA (git or svn)
# defaults to svn
case "$1" in
    git)
        export MESA_VC=git
        export MESA_DIR=${DATA_DIR}/mesa-git-test
        ;;
    *)
        export MESA_VC=svn
        export MESA_DIR=${DATA_DIR}/mesa-svn
        export USE_MESA_TEST=t
        export MESA_TEST_OPTIONS="--force --no-submit --no-svn --no-diff"
        ;;
esac


# if directory is already being tested, exit
if [ -e ${MESA_DIR}/.testing ]; then
    echo "Tests are in-progress"
    exit 1
fi


# commands to check out copy of MESA
case "${MESA_VC}" in

    # test SVN version
    svn)

        # remove old version of MESA directory
        rm -rf ${MESA_DIR}

        # checkout MESA from rsync clone
        svn co https://subversion.assembla.com/svn/mesa^mesa/trunk ${MESA_DIR}
        if [ $? -ne 0 ]
        then
            echo "Failed to checkout SVN"
            exit 1
        fi

        # extract the "true" svn version
        (
            cd ${MESA_DIR}
            svnversion > test.version
            cp test.version data/version_number
        )
        ;;

    # test git version
    git)
        git --git-dir ${MESA_DIR}/.git describe --all --long > ${MESA_DIR}/test.version
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

# mark directory as being tested
touch ${MESA_DIR}/.testing

# submit job to install MESA
export INSTALL_JOBID=$(sbatch --parsable \
                              --ntasks-per-node=${OMP_NUM_THREADS} \
                              --output="${MESA_DIR}/install.log" \
                              --mail-user=${MY_EMAIL_ADDRESS} \
                              ${MY_SLURM_OPTIONS} \
                              install.sh)

# submit job to report build error
# sbatch error.sh -W depend=afternotok:${INSTALL_JOBID}

# next, run the star test suite
# this is part is parallelized, so get the number of tests
cd ${MESA_DIR}/star/test_suite
export NTESTS=$(./count_tests)
cd -

export STAR_JOBID=$(sbatch --parsable \
                           --ntasks-per-node=${OMP_NUM_THREADS} \
                           --array=1-${NTESTS} \
                           --output="${MESA_DIR}/star.log-%a" \
                           --dependency=afterok:${INSTALL_JOBID} \
                           --mail-user=${MY_EMAIL_ADDRESS} \
                           ${MY_SLURM_OPTIONS} \
                           star.sh)

# finally, run the binary test suite
# this is part is parallelized, so get the number of tests
cd ${MESA_DIR}/binary/test_suite
export NTESTS=$(./count_tests)
cd -

export BINARY_JOBID=$(sbatch --parsable \
                             --ntasks-per-node=${OMP_NUM_THREADS} \
                             --array=1-${NTESTS} \
                             --output="${MESA_DIR}/binary.log-%a" \
                             --dependency=afterok:${INSTALL_JOBID}\
                             --mail-user=${MY_EMAIL_ADDRESS} \
                             ${MY_SLURM_OPTIONS} \
                             binary.sh)

# send the email
sbatch --output="${MESA_DIR}/cleanup.log" \
       --dependency=afterany:${STAR_JOBID},afterany:${BINARY_JOBID} \
       ${MY_SLURM_OPTIONS} \
       cleanup.sh

