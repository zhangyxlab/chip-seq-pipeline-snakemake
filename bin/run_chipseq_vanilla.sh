#! /usr/bin/env bash
## run_chipseq_vanilla.sh
## copyleft (c) Ren Lab 2017
## GNU GPLv3 License
############################


function usage(){
echo -e "Usage: $0 -g genome -e E-mail -s server"
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



NTHREADS=12
DIR=$(dirname $0)
LOG=run-$(date +%Y-%m-%d-%H-%M-%S).log
## validate the programs are installed.
. ${DIR}/validate_programs.sh
## load snakemake environment for Renlab
if [ $server == "silencer" ]; then
  source /mnt/silencer2/share/Piplines/environments/python3env/bin/activate
  echo "$(date) # Analysis Began" > $LOG
  snakemake -p -k --snakefile ${DIR}/Snakefile --cores $NTHREADS \
  --config GENOME=$genome BWA_INDEX_PATH=/mnt/silencer2/share/bwa_indices/ \
  2> >(tee -a $LOG >&2) 
  echo "$(date) # Analysis finished" >> $LOG
  echo "See attachment for the running log. 
  Your results are saved in: 
  $(pwd)"  | mail -s "ChIP-seq analysis Done" -a $LOG  $email

elif [ $server -eq TSCC ]; then 
  unset PYTHONPATH
  source /home/shz254/py34env/bin/activate
  if [ ! -d pbslog ]; then mkdir pbslog; fi
    echo "$(date) # Analysis Began" > $LOG

  snakemake --snakefile ${DIR}/Snakefile -p  -k -j 1000 --cluster \
  --config GENOME=$genome BWA_INDEX_PATH=/oasis/tscc/scratch/bil022/HiC/ref/
  "qsub -l nodes=1:ppn={threads} -N {rule} -M $email -q hotel 
  -o pbslog/{rule}.pbs.out -e pbslog/{rule}.pbs.err" \
  --jobscript ${DIR}/scripts/jobscript.pbs --jobname "{rulename}.{jobid}.pbs" 
  2> >(tee -a $LOG >&2)
  echo "$(date) # Analysis finished" >> $LOG
  echo "See attachment for the running log. 
  Your results are saved in: 
  $(pwd)"  | mail -s "ChIP-seq analysis Done" -a $LOG  $email
else 
  echo -e "Invalide server option: $server"; exit 1; 
fi
