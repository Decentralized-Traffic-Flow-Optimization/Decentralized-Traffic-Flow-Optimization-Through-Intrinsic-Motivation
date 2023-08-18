#!/bin/bash
#
#SBATCH --job-name=traffic_flow_emp
#SBATCH --output=traffic_flow_emp-%j.out
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=50
##SBATCH --cpus-per-task=1
#SBATCH --partition=compute
##SBATCH --partition=gpu
##SBATCH --partition=lque
#SBATCH --time=7-00:00:00
#SBATCH --mem-per-cpu=2G
##SBATCH --mem=123G
#SBATCH --mail-user=himaja.papala@sjsu.edu
#SBATCH --mail-type=END

module load julia

julia --project --threads=1 traffic_flow_empowerment.jl
