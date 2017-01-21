#!/bin/bash

#PBS -N cleanup
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

# make output file
cat star.log-* > star.log

# make output file
echo "MESA Test Suite r${VERSION}" > output.txt
grep "fail" star.log >> output.txt
grep "fail" binary.log >> output.txt

# send full results via email
mail -s "MESA Test Suite r${VERSION}" -a star.log -a binary.log -a install.log ${MY_EMAIL_ADDRESS} < output.txt

# clean stuff up
rm install.log star.log-* star.log binary.log 
