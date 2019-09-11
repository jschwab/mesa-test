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
export MESA_OP_MONO_DATA_PATH=${HOME}/OP4STARS_1.3/mono
export MESA_OP_MONO_DATA_CACHE_FILENAME=${HOME}/OP4STARS_1.3/mono/op_mono_cache.bin

export MESA_BASE_DIR=/data/users/jwschwab

# pick version control system; default is svn
case "$1" in
    git)
        export MESA_VC=git
        export MESA_DIR=${MESA_BASE_DIR}/mesa-git-test
        ;;
    *)
        export USE_MESA_TEST=t
        export MESA_VC=svn
        export MESA_DIR=${MESA_BASE_DIR}/mesa-svn-test
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
export INSTALL_JOBID=$(sbatch --parsable -o ${MESA_DIR}/install.log install.sh)

# submit job to report build error
# sbatch error.sh -W depend=afternotok:${INSTALL_JOBID}

# next, run the star test suite
# this is part is parallelized, so get the number of tests
cd ${MESA_DIR}/star/test_suite
export NTESTS=$(./count_tests)
cd -

STAR_JOBID=$(sbatch --parsable -o ${MESA_DIR}/star.log --dependency=afterok:${INSTALL_JOBID} --array=1-${NTESTS} star.sh)

# finally, run the binary test suite
# this is part is parallelized, so get the number of tests
cd ${MESA_DIR}/binary/test_suite
export NTESTS=$(./count_tests)
cd -

BINARY_JOBID=$(sbatch --parsable -o ${MESA_DIR}/binary.log --dependency=afterok:${INSTALL_JOBID} --array=1-${NTESTS} binary.sh)

# send the email
sbatch --dependency=afterany:${STAR_JOBID},afterany:${BINARY_JOBID} cleanup.sh
