#!/bin/bash

#SBATCH --job-name=cleanup
#SBATCH --partition=defq
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --export=ALL
#SBATCH --time=0:10:00
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=jwschwab@ucsc.edu

# get MESA version

cd ${MESA_DIR}
VERSION_DATA=$(<data/version_number)
VERSION_VC=$(<test.version)

# make version string "real (reported)"
VERSION="${VERSION_VC} (${VERSION_DATA})"

# send full results via email
mail -s "MESA Install Failed r${VERSION}" ${MY_EMAIL_ADDRESS} < install.log
