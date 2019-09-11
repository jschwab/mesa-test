#!/bin/bash
#set -x
set -euxo pipefail

update_mesa() {

    # relevant directories
    MESA_GIT_DIR=/data/users/jwschwab/mesa.git
    MESA_TEST_DIR=/data/users/jwschwab/mesa-git-test

    # clean up and checkout pushed branch
    rm -rf ${MESA_TEST_DIR}
    git --git-dir=${MESA_GIT_DIR} worktree prune
    git --git-dir=${MESA_GIT_DIR} worktree add --checkout ${MESA_TEST_DIR} ${1}

    # now spawn a test job
    (
        cd /home/jwschwab/mesa-test
        ./test-mesa.sh git run
    )


}

# From http://stackoverflow.com/a/13057643
while read oldrev newrev refname
do
    branch=$(git rev-parse --symbolic --abbrev-ref $refname)

    case "$branch" in
        master)
            continue
            ;;
        *)
            update_mesa $branch
            ;;
    esac

done
