#!/usr/bin/env bash

$(echo $LOADEDMODULES | grep singularity >& /dev/null) || ml singularity >& /dev/null

. /usr/local/current/singularity/app_conf/sing_binds

export SINGULARITY_BINDPATH="${SINGULARITY_BINDPATH},/usr/local/apps"

singularity exec --nv "$(dirname $(readlink -f ${BASH_SOURCE[0]}))/cellbender-0.3.2.sif" "$(basename $0)" "$@"