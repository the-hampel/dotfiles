#!/bin/bash


function ccpe-15 () {
 
 # check if palsd for user is running
 if ( systemctl -q is-active palsd@${USER}.service  ) ; then

     ml purge

     singularity exec --rocm --env-file /opt/share/singularity/ccpe/etc/${USER}/palsd.conf \
         --env SINGULARITYENV_PREPEND_LD_LIBRARY_PATH="/usr/lib64:/.singularity.d/libs"\
         --bind /opt/share/singularity/ccpe/log:/var/log \
         --bind /opt/share/singularity/ccpe/scripts:/opt/scripts \
         --bind /opt/share/singularity/ccpe/etc/${USER}:/etc/pals \
         --bind /var/run/munge \
         --hostname localhost \
         /opt/share/singularity/ccpe/cce-15.0.1_rocm-5.3.0.sif bash -rcfile /opt/scripts/ccpe_bashrc_cce-15.0.1

 else
     echo "palsed@${USER}.service not running "
 fi

}

function ccpe-19 () {
 
 # check if palsd for user is running
 if ( systemctl -q is-active palsd@${USER}.service  ) ; then
    ml purge

    # get env variables to pass to apptainer
    SING_ENV_LIST=""
    while IFS='=' read -r key val; do
        # Reconstruct the variable safely (preserve = and spaces)
        var="${key}=${val}"
        echo "$var"

        # Escape any single quotes for safe shell eval
        safe_var=$(printf "%s" "$var" | sed "s/'/'\\\\''/g")

        # Append safely quoted env var
        SING_ENV_LIST+=" --env '${safe_var}'"
    done < <(env | grep -E '^(SLURM|PALS|SRUN|PMI|HOST|USER|SLINGSHOT|ROCR_VISIBLE_DEVICES)=')

    export APPTAINERENV_PS1='cpe::\[\e[00m\] \h > '
    export APPTAINERENV_PREPEND_PATH="/opt/rocm/bin"
    export APPTAINERENV_ROCM_PATH="/opt/rocm"
    export APPTAINERENV_FFTW_ROOT="/opt/cray/pe/fftw/default/x86_milan"
    # --- Run the container ---
    eval "apptainer run --rocm --cleanenv ${SING_ENV_LIST} \
        --env-file /opt/share/singularity/ccpe/etc/${USER}/palsd.conf \
        --bind /opt/share/singularity/ccpe/log:/var/log \
        --bind /opt/share/singularity/ccpe/scripts:/opt/scripts \
        --bind /opt/share/singularity/ccpe/etc/${USER}:/etc/pals \
        --bind /opt/rocm:/opt/rocm \
        --bind /var/run/munge \
        --bind /scratch/${USER}:/scratch/${USER} \
        /scratch/hampel/container-images/cpe_2503/cpe_2503_lumi_extend.sif"
 else
     echo "palsed@${USER}.service not running "
 fi
}

function ubuntu-25 () {
 
  ml purge

  # get env variables to pass to apptainer
  SING_ENV_LIST=""
  for var in `env | grep -e ^SLURM -e ^PALS -e ^SRUN -e ^PMI -e ^HOST -e ^USER -e ^SLINGSHOT`; do
      SING_ENV_LIST+=" --env $var"
  done

  export APPTAINERENV_PS1='ub25::\[\e[00m\] \h > '
  export APPTAINERENV_PREPEND_PATH="/opt/rocm/bin"
  export APPTAINERENV_ROCM_PATH="/opt/rocm"
  export APPTAINERENV_LD_LIBRARY_PATH=/opt/rocm/lib:$LD_LIBRARY_PATH
  export APPTAINERENV_LIBRARY_PATH=/opt/rocm/lib:$LIBRARY_PATH
  apptainer run --rocm --cleanenv ${SING_ENV_LIST} \
     --bind /opt/rocm:/opt/rocm \
     --bind /scratch/${USER} \
     /scratch/hampel/container-images/ubuntu25/ub25_gcc15_ompoff.sif 
}
