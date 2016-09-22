#!/bin/bash

#PBS -N cleanup
#PBS -l nodes=1:ppn=16
#PBS -l walltime=00:05:00
#PBS -V

# get MESA version
cd ${MESA_DIR}
VERSION=$(<data/version_number)

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

