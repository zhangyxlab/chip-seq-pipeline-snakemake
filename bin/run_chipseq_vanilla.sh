#! /usr/bin/env bash
## run_chipseq_vanilla.sh
#######################################################################
## Copyleft (c) 2017 Bing Ren Lab
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#######################################################################


function usage(){
echo -e "Usage: $0 -g genome -e E-mail -s server"
echo -e "\t-g [genome]: hg19, mm10, etc."
echo -e "\t-e [email]: email address."
echo -e "\t-s [server]: silencer or TSCC"
exit 1
}

while getopts "g:e:s:" OPT
do
  case $OPT in 
    g) genome=$OPTARG;;
    e) email=$OPTARG;;
    s) server=$OPTARG;;
    \?) 
      echo "Invalid option: -$OPTARG" >& 2
      usage
      exit 1;;
    :)
        echo "Option -$OPTARG requires an argument." >&2
        usage
        exit 1
        ;;
  esac
done

if [ $# -eq 0 ]; then usage; exit; fi
if [ -z ${email+x} ]; 
  then echo -e "Please provide E-mail"; usage; exit; fi
if [ -z ${genome+x} ]; then 
  echo -e "Please provide genome, eg. mm10, hg19"; usage;exit; fi
if [ -z ${server+x} ]; 
  then echo -e "Please tell us the server, eg. silencer, TSCC"; usage;exit; fi


NTHREADS=30
DIR=$(dirname $0)
LOG=run-$(date +%Y-%m-%d-%H-%M-%S).log
## validate the programs are installed.
. ${DIR}/validate_programs.sh
## load snakemake environment for Renlab
if [ $server == "silencer" ]; then
  source /mnt/silencer2/share/Piplines/environments/python3env/bin/activate
  ### unlock the directory
  touch Snakefile
  snakemake --unlock 
  rm Snakefile
  ## started analysis
  echo "$(date) # Analysis Began" > $LOG
  nice -n 19 snakemake -p -k --ri --snakefile ${DIR}/Snakefile --cores $NTHREADS \
  --config GENOME=$genome BWA_INDEX_PATH=/projects/ps-renlab/share/bwa_indices/ \
  2> >(tee -a $LOG >&2) 
  echo "$status"
  echo "$(date) # Analysis finished" >> $LOG
  [[ $email =~ @ ]] && (
  echo "See attachment for the running log. 
  Your results are saved in: 
  $(pwd)"  | mail -s "ChIP-seq analysis Done" -a $LOG  $email )

elif [ $server == "TSCC" ]; then 
#  module load python
  unset PYTHONPATH
  source /projects/ps-renlab/share/Pipelines/environments/python3env_TSCC/bin/activate
  ### unlock the directory
  touch Snakefile
  snakemake --unlock
  rm Snakefile
  ## started analysis
  if [ ! -d pbslog ]; then mkdir pbslog; fi
    echo "$(date) # Analysis Began" > $LOG
  snakemake --snakefile ${DIR}/Snakefile -p  -k -j 1000 --ri \
  --config GENOME=$genome BWA_INDEX_PATH=/projects/ps-renlab/share/bwa_indices/ \
  --cluster "qsub -l nodes=1:ppn={threads} -N {rule} -q hotel -o pbslog/{wildcards.sample}.{rule}.pbs.out -e pbslog/{wildcards.sample}.{rule}.pbs.err" \
  --jobscript ${DIR}/../scripts/jobscript.pbs --jobname "{rulename}.{jobid}.pbs" \
  2> >(tee -a $LOG >&2)
  echo "$(date) # Analysis finished" >> $LOG
  [[ $email =~ @ ]] && (
  echo "See attachment for the running log. 
  Your results are saved in: 
  $(pwd)"  | mail -s "ChIP-seq analysis Done" -a $LOG  $email 
  )
else 
  echo -e "Invalide server option: $server"; exit 1; 
fi

