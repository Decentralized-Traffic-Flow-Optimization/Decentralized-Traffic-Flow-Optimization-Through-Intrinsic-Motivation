#!/bin/bash
#
#SBATCH --job-name=0.2_test
#SBATCH --output=t_emp_0.2-%j_correct_Pv.out
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=50
##SBATCH --cpus-per-task=1
##SBATCH --partition=compute
#SBATCH --partition=gpu
##SBATCH --partition=lque
#SBATCH --time=7-00:00:00
#SBATCH --mem-per-cpu=2G
##SBATCH --mem=123G
#SBATCH --mail-user=himaja.papala@sjsu.edu
#SBATCH --mail-type=END

module load julia

##srun julia --project traffic_flow_agents_latest_rear_car_info.jl
##srun julia --project channel_emp_2lane.jl
julia --project --threads=1 traffic_flow_agents_standard.jl
##julia --project --threads=1 E_s_plots.jl