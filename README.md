# Dcentralized-traffic-flow-optimization
This code is a julia implementation of decentralized traffic flow optimization using intrinsic motivation. 

###Files###
- `NaSch_model.jl`: Contains the implementation of the Nagel-schreckenberg traffic flow simulation model.
- `channel_empowerment.jl`: Contains functions to calculate channel, empowerment and expected empowermen for an agent.
- `traffic_flow_empowerment.jl`: Contains functions to calculate traffic flow on the road containing normal cars and different ratios of agents for different densities.
- Each file containd paramater descriptions at the top

###Prerequisites###

- You need to have Julia installed on your system. You can download it from [julialang.org](https://julialang.org/downloads/).
- Add necessary packages like (StatsBase, DataStructures, Plots, Statistics, Distributed, LaTeXStrings, etc..) in julia
- you can check https://datatofish.com/install-package-julia/ on how to add packages in julia
- 
###Customization###
-NOTE: This code uses multiprocessing capabilities in HPC (High Performance computer). So, please modify "addprocs_slurm()" in "traffic_flow_empowerment.jl" file to number of processes that can be supported by your computer.
- You can modify simulation parameters such as road length, density, v_max, braking probability, empowerment horizon and simulation steps in the ####main### part of traffic_flow_empowerment.jl file .

###How to run in HPC###
- Extract the contents of this zip file to a directory of your choice in HPC.
- Edit the number of nodes, number of tasks per node, partition name and alloted time  in run.sh .
- Edit add "addprocs_slurm( <num_procs>)" in "traffic_flow_empowerment.jl" file where <num_procs>= nodes * number of tasks per node.
- Open a terminal.
- Navigate to the directory where you placed the Julia files.
- run "sbatch run.sh" command in the terminal.
- To learn more on how to submit slurm jobs check https://support.ceci-hpc.be/doc/_contents/QuickStart/SubmittingJobs/SlurmTutorial.html
  
###How to run in computer###
- Extract the contents of this zip file to a directory of your choice.
- Open a terminal or command prompt.
- Navigate to the directory where you extracted the contents of this zip file.
- Remove using ClusterManagers line in traffic_flow_empowerment.jl and replace "addprocs_slurm" with "addprocs".
- Adjust the number of processes in addprocs according to your computer.
- To run the traffic flow simulation and empowerment analysis, execute the following command:

   julia traffic_flow_empowerment.jl

- The simulation will run, and you'll see the output whenever println statements are encountered in julia file.
Note: The simulation would take days to run depending on the simulation time, road length and density

###Results###
The results of the simulation and analysis will be displayed in the terminal. 
Any output files or visualizations generated will be saved in the same directory.
