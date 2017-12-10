#!/bin/bash
set -euxo pipefail

# first argument chooses where to get MESA (git or svn)
# second argument chooses which kind of test to run

# if set, use mesa_test gem
# for me, I always use it with svn
# export USE_MESA_TEST=t
export MESA_TEST_OPTIONS="--force --no-submit"

# for MESA test, need to set the
case "$2" in
    run_and_diff)
        export MESA_TEST_COMMAND=each_test_run_and_diff
        export MESA_TEST_OPTIONS="${MESA_TEST_OPTIONS}"
        ;;
    run)
        export MESA_TEST_COMMAND=each_test_run
        export MESA_TEST_OPTIONS="${MESA_TEST_OPTIONS} --no-diff"
        ;;
    *)
        exit
        ;;
esac


# choose SDK version
export MESASDK_VERSION=20160129

# set OP opacities
export MESA_OP_MONO_DATA_PATH=/pfs/jschwab/OP4STARS_1.3/mono
export MESA_OP_MONO_DATA_CACHE_FILENAME=/pfs/jschwab/OP4STARS_1.3/mono/op_mono_cache.bin

# pick version control system; default is svn
case "$1" in
    git)
        export MESA_VC=git
        export MESA_DIR=/pfs/jschwab/mesa-git-test
        ;;
    *)
        export USE_MESA_TEST=t
        export MESA_VC=svn
        export MESA_DIR=/pfs/jschwab/mesa-svn-test
        ;;
esac

# if directory is already being tested, exit
if [ -e ${MESA_DIR}/.testing ]; then
    echo "Tests are in-progress"
    exit 1
fi

# set other important enviroment variables
export OMP_NUM_THREADS=16
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

        # the sourceforge site is unreliable
        # therefore we keep an rsync-ed clone around
        # we will checkout from this directory
        export MESA_SVN_RSYNC=/pfs/jschwab/mesa-svn-rsync
        rsync -av svn.code.sf.net::p/mesa/code/* ${MESA_SVN_RSYNC}
        if [ $? -ne 0 ]
        then
            echo "Failed to sync SVN with sourceforge"
            exit 1
        fi

        # remove old version of MESA directory
        rm -rf ${MESA_DIR}

        # checkout MESA from rsync clone
        svn co file://${MESA_SVN_RSYNC}/trunk ${MESA_DIR}
        if [ $? -ne 0 ]
        then
            echo "Failed to checkout SVN"
            exit 1
        fi

        # extract the "true" svn version
        (
            cd ${MESA_DIR}
            svnversion > data/version_number
            cp data/version_number test.version
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
export INSTALL_JOBID=$(qsub install.sh -o ${MESA_DIR}/install.log)

# submit job to report build error
# qsub error.sh -W depend=afternotok:${INSTALL_JOBID}

# next, run the star test suite
# this is part is parallelized, so get the number of tests
cd ${MESA_DIR}/star/test_suite
export NTESTS=$(./count_tests)
cd -

STAR_JOBID=$(qsub star.sh -o ${MESA_DIR}/star.log -W depend=afterok:${INSTALL_JOBID} -t 1-${NTESTS})

# finally, run the binary test suite
# this is part is parallelized, so get the number of tests
cd ${MESA_DIR}/binary/test_suite
export NTESTS=$(./count_tests)
cd -

BINARY_JOBID=$(qsub binary.sh -o ${MESA_DIR}/binary.log -W depend=afteranyarray:${STAR_JOBID} -t 1-${NTESTS})

# send the email
qsub cleanup.sh -W depend=afteranyarray:${BINARY_JOBID}
