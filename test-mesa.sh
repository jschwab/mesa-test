#!/bin/bash -x

# set important enviroment variables
export MESA_DIR=/pfs/jschwab/mesa-svn-test
export OMP_NUM_THREADS=16
export MESA_CACHES_DIR=/tmp

# if we want to load our own copy of SVN, it must be 1.5.9
# newer versions fail (as of 2016-09-21), though the version on the
# login node (which is 1.6.11) appears to work
# 
# module load subversion/1.5.9


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
cd ${MESA_DIR}
svnversion > svnversion.out
cd -

# submit job to install MESA
export INSTALL_JOBID=$(qsub install.sh -o ${MESA_DIR}/install.log)

# next, run the star test suite
# this is part is parallelized, so get the number of tests
cd ${MESA_DIR}/star/test_suite
export NTESTS=$(./count_tests)
cd -

STAR_JOBID=$(qsub star.sh -o ${MESA_DIR}/star.log -W depend=afterok:${INSTALL_JOBID} -t 1-${NTESTS})

# finally, run the binary test suite
# this part is not parallelized
BINARY_JOBID=$(qsub binary.sh -o ${MESA_DIR}/binary.log -W depend=afterok:${INSTALL_JOBID})

# send the email
qsub cleanup.sh -W depend=afteranyarray:${STAR_JOBID},afterany:${BINARY_JOBID}

