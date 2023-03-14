#!/bin/bash
#SBATCH --account=rpp-blairt2k
#SBATCH --time=1-0:00:00
#SBATCH --nodes=1
#SBATCH --mem=192000M
#SBATCH --ntasks-per-node=32
#SBATCH --gpus-per-node=v100l:4
#SBATCH --output=/scratch/junjiex/log/WCTEmPMT_test/NNtrain/watchmal_%x.%A.out
#SBATCH --error=/scratch/junjiex/log/WCTEmPMT_test/NNtrain/watchmal_%x.%A.err

# Run WatChMaL in singularity after copying large files/directories to node's local disk
# usage: run_watchmal_jobs.sh [-t] -i singularity_image -c path_to_copy [-c another_path_to_copy] -w watchmal_directory -- watchmal_command [watchmal command options]
# -t                          Run in test mode (don’t copy files, run watchmal command with “-c job” option to print out the full config without actually running)
# -i singularity_image        Location of the singularity image to use
# -c path_to_copy             Copy file to node’s local storage for faster training
# -w watchmal_directory       Location of WatChMaL repository
# -- watchmal_command [opt]   Full command to run inside singularity is anything that comes after --

module load python/3.8.10
module load scipy-stack

PATHS_TO_COPY=()
while [ $# -gt 0 ]; do
  case "$1" in
    -t)
      TEST=true
      ;;
    -i)
      shift
      SINGULARITY_FILE="$(readlink -f $1)"
      ;;
    -w)
      shift
      WATCHMAL_DIR="$1"
      ;;
    -c)
      shift
      PATHS_TO_COPY+=("$1")
      ;;
    --)
      shift
      break
      ;;
  esac
  shift
done

if [ -z $WATCHMAL_DIR ]; then
  echo "WatChMaL directory not provided. Use -w option."
  exit 1;
fi

echo "entering directory $WATCHMAL_DIR"
cd "$WATCHMAL_DIR"

if [ -z $SINGULARITY_FILE ]; then
  echo "Singularity image file not provided. Use -i option."
  exit 1;
fi

export SINGULARITY_BIND="/project/6008045,${HOME}"

if [ -z $TEST ]; then
  for PATH_TO_COPY in "${PATHS_TO_COPY[@]}"; do
    echo "copying $PATH_TO_COPY to $SLURM_TMPDIR"
    rsync -ahvPR "$PATH_TO_COPY" "$SLURM_TMPDIR"
    export SINGULARITY_BIND="${SINGULARITY_BIND},${SLURM_TMPDIR}/${PATH_TO_COPY##*/./}:${PATH_TO_COPY}"
  done
  SINGULARITY_FILE_MOVED="$SLURM_TMPDIR/${SINGULARITY_FILE##*/}"
  echo "copying singularity file from $SINGULARITY_FILE to $SINGULARITY_FILE_MOVED"
  rsync -ahvP "$SINGULARITY_FILE" "$SINGULARITY_FILE_MOVED"
  echo "running command:"
  echo "  $@"
  echo "inside $SINGULARITY_FILE_MOVED"
  echo "with binds: $SINGULARITY_BIND"
  echo ""
  singularity exec --nv --bind "${SINGULAIRTY_BIND}" "$SINGULARITY_FILE_MOVED" $@
else
  for PATH_TO_COPY in "${PATHS_TO_COPY[@]}"; do
    echo "skipping copying $PATH_TO_COPY to $SLURM_TMPDIR"
  done
  echo "running command:"
  echo "  $@ -c job"
  echo "with binds: $SINGULARITY_BIND"
  echo "inside $SINGULARITY_FILE"
  echo ""
  singularity exec --bind "${SINGULARITY_BIND}" "$SINGULARITY_FILE" $@ -c job
fi

