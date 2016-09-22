#!/bin/bash

#PBS -N install
#PBS -l nodes=1:ppn=16
#PBS -l walltime=02:00:00
#PBS -V

# load SDK
module load mesasdk

# build MESA
cd $MESA_DIR
./clean
./install
