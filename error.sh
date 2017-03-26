#!/bin/bash

#PBS -N error
#PBS -l nodes=1:ppn=16
#PBS -l walltime=00:05:00
#PBS -V
#PBS -k n

# get MESA version
cd ${MESA_DIR}
VERSION_DATA=$(<data/version_number)
VERSION_SVN=$(<svnversion.out)

# make version string "real (reported)"
VERSION="${VERSION_SVN} (${VERSION_DATA})"

# send full results via email
mail -s "MESA Install Failed r${VERSION}" ${MY_EMAIL_ADDRESS} < install.log
