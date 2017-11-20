#!/bin/bash
set -euxo pipefail

# if set, use mesa_test gem
# export USE_MESA_TEST=t

# choose which kind of test to run
# (no effect if USE_MESA_TEST=t)
export MESA_TEST_COMMAND=each_test_run_and_diff

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
        export MESA_VC=svn
        export MESA_DIR=/pfs/jschwab/mesa-svn-test
        ;;
esac


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
            svnversion > test.version
        )
        ;;

    # test git version
    git)
        git --git-dir ${MESA_DIR}/.git describe --all --long > ${MESA_DIR}/test.version
        ;;
esac

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

BINARY_JOBID=$(qsub binary.sh -o ${MESA_DIR}/binary.log -W depend=afterok:${INSTALL_JOBID} -t 1-${NTESTS})

# send the email
qsub cleanup.sh -W depend=afterokarray:${STAR_JOBID}:${BINARY_JOBID}
