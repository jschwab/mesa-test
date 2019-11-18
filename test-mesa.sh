#!/bin/bash
set -euxo pipefail

# first argument chooses where to get MESA (git or svn)

# if set, use mesa_test gem
# for me, I always use it with svn
# export USE_MESA_TEST=t
export MESA_TEST_OPTIONS="--force --no-submit"

# for MESA test, need to set the
export MESA_TEST_COMMAND=each_test_run
export MESA_TEST_OPTIONS="${MESA_TEST_OPTIONS} --no-svn --no-diff"

# choose SDK version
export MESASDK_VERSION=20190830

# set OP opacities
export MESA_OP_MONO_DATA_PATH=${DATA_DIR}/OP4STARS_1.3/mono
export MESA_OP_MONO_DATA_CACHE_FILENAME=${DATA_DIR}/OP4STARS_1.3/mono/op_mono_cache.bin
rm -f ${MESA_OP_MONO_DATA_CACHE_FILENAME}

# parent directory of MESA_DIR
export MESA_BASE_DIR=${DATA_DIR}

# set email address for SLURM and for cleanup output
export MY_EMAIL_ADDRESS=jwschwab@ucsc.edu

# choose SLURM options (used for all sbatch calls)
export MY_SLURM_SETTINGS="--partition=defq"

# pick version control system; default is svn
case "$1" in
    git)
        export MESA_VC=git
        export MESA_DIR=${MESA_BASE_DIR}/mesa-git-test
        ;;
    *)
        export USE_MESA_TEST=t
        export MESA_VC=svn
        export MESA_DIR=${MESA_BASE_DIR}/mesa-svn
        ;;
esac

# if directory is already being tested, exit
if [ -e ${MESA_DIR}/.testing ]; then
    echo "Tests are in-progress"
    exit 1
fi

# set other important enviroment variables
export OMP_NUM_THREADS=40
#export MESA_CACHES_DIR=/tmp/mesa-cache

clean_caches(){
    # clean up cache dir if needed
    if [ -n "${MESA_CACHES_DIR}" ]; then
        rm -rf ${MESA_CACHES_DIR}
        mkdir -p ${MESA_CACHES_DIR}
    fi
}

export -f clean_caches

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

# mark directory as being tested
touch ${MESA_DIR}/.testing

# submit job to install MESA
export INSTALL_JOBID=$(sbatch --parsable \
                              --ntasks-per-node=${OMP_NUM_THREADS} \
                              --output="${MESA_DIR}/install.log" \
                              --mail-user={$MY_EMAIL_ADDRESS} \
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
                           --mail-user={$MY_EMAIL_ADDRESS} \
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

