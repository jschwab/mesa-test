#!/bin/bash -x

#SBATCH --job-name=cleanup
#SBATCH --nodes=1
#SBATCH --export=ALL
#SBATCH --time=0:10:00
#SBATCH --mail-type=FAIL

# wait a bit for final jobs to finish. there seems to be a race
# condition where the output from the last job to finish isn't on disk
# at the time the cleanup script is executed
sleep 60

# get MESA version
cd ${MESA_DIR}
VERSION_DATA=$(<data/version_number)
VERSION_VC=$(<test.version)

# make version string "real (reported)"
VERSION="${VERSION_VC} (${VERSION_DATA})"

# make output files
cat star.log-* > star.log
cat binary.log-* > binary.log
cat astero.log-* > astero.log

# make output file
echo "MESA Test Suite r${VERSION}" > output.txt
echo ${MESA_TEST_COMMAND} >> output.txt
grep "fail" star.log >> output.txt
grep "fail" binary.log >> output.txt
grep "fail" astero.log >> output.txt

# send full results via email
mail -v -s "MESA Test Suite r${VERSION}" -a star.log -a binary.log -a astero.log -a install.log -q output.txt ${MY_EMAIL_ADDRESS} < /dev/null

# clean stuff up
# rm install.log star.log-* star.log binary.log-* binary.log

# indicate active testing is over
rm ${MESA_DIR}/.testing
