using Distributed
#remove ClusterManagers if it is not run in HPC##
using ClusterManagers
addprocs_slurm(100, exeflags=["--project", "--threads=1"])
##use addproc(100, exeflags=["--project", "--threads=1"]) instead, if you are not running in HPC##
@everywhere include("NaSch_model.jl")
@everywhere include("channel_empowerment.jl")
@everywhere using Random, Statistics, Plots, Base.Threads, LinearAlgebra,  BSON , DistributedArrays, LaTeXStrings 

###Parameters ####
#R: road vector with cars (-1: empty cell, +ve integer: car)
#L: road length
#N: number of cars
#vₘ: maximum velocity allowed
#ρ: density
#p_brake: braking probability
#Tₕ: empowerment horizon
#Tₛ: simulation time
#x: position of agent on the road
#X̂: vector of positions of agents
################################

@everywhere function P_transition( p_brake :: Float64, ρ :: Float64)
    ##### calculate transition Probability P(v′|v)##########
    Pv= zeros(Float64,vₘ+1, vₘ+1)
    rl=100000
    R, _ =  NaSch_road(rl,ρ,vₘ) 
    T=1e6
    for t in 1:T
     Rc= accelerate(rl,R,vₘ) 
     Rc= breaking(rl,Rc)
     Rc= random_breaking(rl,Rc,p_brake)
     @inbounds @simd for i in 1: rl
         if R[i] >=0
             v_old= R[i]
             v_new=Rc[i]
             Pv[v_old+1, v_new+1] +=1
         end
     end 
     R=displace(rl, Rc)
    end
    #normalize Pv
    sum_P= sum(Pv, dims=2)
    Pv= Pv./sum_P
    # replace NaN values with zeros
    Pv[isnan.(Pv)] .= 0
    Pv
 end

 @everywhere function get_position_agents(R :: Vector{Int64}, n :: Int64, percentage :: Int64)
    ###randomly assign certain % of cars as agents########
    num_agents= ceil(Int64, (percentage/100)*n)
    cars= findall(x -> x≠ -1, R)
    X̂=sample(cars, num_agents, replace=false)
    sort(X̂)
end

@everywhere function traffic_flow_emp_mp(R :: Vector{Int64}, N :: Int64, X̂ :: Vector{Int64}, p_brake :: Float64,  Tₛ:: Int64, Tₕ:: Int64, Pᵥ::Array{floatType, 2})
    #### traffic flow calculation with empowered agents###########
    L = length(R)
    sim = zeros(Int, Tₛ, L)
    Rc=copy(R)
    v_avgs=[]
    for t in 1:Tₛ
        # select action for agent according to empowerment
        results = pmap(x -> Empowerment_action(L, Rc, N, x, vₘ, Pᵥ, Tₕ), X̂)
        vₐ, E_a = [(r[1], r[2]) for r in results] |> (k -> (collect(first.(k)), collect(last.(k))))
        for i in eachindex(X̂)
            #check if selected action causes collisions, if so, reduce the action/velocity to Δ
            Δ, xₙ = Delta_agent(L, Rc, X̂[i], N)
            vₐ[i] =min(vₐ[i], Δ)
        end
        
        Rc[X̂] .= -2 #replace agents with -2 so that NaSch update are not applied to them

        #Do NaSch updates on normal cars
        Rc = accelerate(L, Rc, vₘ)
        Rc = breaking(L, Rc)
        Rc = random_breaking(L, Rc, p_brake)
        Rc[X̂] .= vₐ #relace agents with their velocities
        Rc = displace(L, Rc)
        sim[t, :] = [j == -1 ? 0 : 1 for j in Rc]
        #collect velocities of all cars on the road every 5th time steps after 1000 time steps
        if t ≥1000 && t%5==0
            v=space_avg_velocity(Rc)
            push!(v_avgs, v)
        end
        #update the positions of agents
        for i in eachindex(X̂)
            X̂[i]= X̂[i] +vₐ[i]
            if X̂[i] > L
                X̂[i]= mod(X̂[i],L)
            end
        end
    end
    #calculate flow
    F_v= sum(v_avgs)/size(v_avgs)[1]
    F_v, sim
end

@everywhere function process_density(vₘ :: Int64,L :: Int64, p_brake:: Float64, Tₛ :: Int64, Tₕ :: Int64, ρ :: Float64)
    
    #randomly initialize the road with cars
    R, N = NaSch_road(L, ρ, vₘ)
    #flow with no agents
    Fv_0, sim0 = traffic_flow_no_agent(L, R, vₘ, p_brake, Tₛ)
    #get transition probabilities of velocities of normal cars
    Pv = P_transition(p_brake, ρ)
    @time begin
        #flow with 10% agents
        X̂= get_position_agents(R, N, 10)
        Fv_10, sim10 = traffic_flow_emp_mp(R, N, X̂, p_brake, Tₛ, Tₕ, Pv)
    end
    @time begin
        #flow with 20% agents
        X̂ = get_position_agents(R, N, 20)
        Fv_20,  sim20 = traffic_flow_emp_mp(R, N, X̂, p_brake, Tₛ, Tₕ,Pv)
    end
    @time begin
        #flow with 50% agents
        X̂ = get_position_agents(R, N, 50)
        Fv_50, sim50 = traffic_flow_emp_mp(R, N, X̂, p_brake, Tₛ, Tₕ, Pv)
    end
    @time begin
        #flow with 70% agents
        X̂ = get_position_agents(R, N, 70)
        Fv_70, sim70 = traffic_flow_emp_mp(R, N, X̂, p_brake, Tₛ, Tₕ, Pv)
    end

    file_path = "./Flow_$(ρ)density_$(L)road_legthn_$(p_brake)braking_prob_$(Tₕ)step_emp_$(Tₛ)simulation_timesteps.bson"
    BSON.@save file_path Fv_0 Fv_10  Fv_20 Fv_50 Fv_70 Pv sim0 sim10 sim20 sim50 sim70
    return (Fv_0, Fv_10, Fv_20, Fv_50, Fv_70)
end


######_main_######

vₘ=5
L=1000
p_brake=0.2
Tₛ =5000
Tₕ=3
densities=[]
###get range of denities#####
for ρ in 0.02:0.02:0.7
    push!(densities, ρ)
end
println(densities)
results = pmap(ρ -> process_density(vₘ,L, p_brake, Tₛ, Tₕ, ρ), densities)
( F0, F10, F20, F50,  F70) = 
    ([res[1] for res in results],
     [res[2] for res in results],
     [res[3] for res in results],
     [res[4] for res in results],
     [res[5] for res in results]
     )

println("densities: ", densities)
println("velocity flow 0: ", F0)
println("velocity flow 10: ", F10)
println("velocity flow 20: ", F20)
println("velocity flow 50: ", F50)
println("velocity flow 70: ", F70)
flush(stdout)  
plot(densities, F0, linewidth=2, xlabel=L"density (ρ)", ylabel=L"flow (j)",xtickfontsize=6, label=L"\mathbf{0\%\ \ agents}" , legend=:topright)
plot!(densities,F10, linewidth=2, label=L"\mathbf{10\%\ \ agents}" )
plot!(densities,F20, linewidth=2, label=L"\mathbf{20\%\ \ agents}" )
plot!(densities,F50, linewidth=2, label=L"\mathbf{50\%\ \ agents}")
plot!(densities,F70, linewidth=2, label=L"\mathbf{70\%\ \ agents}") 
# Save the plot to the current directory
savefig("flow_plot.png")
rmprocs(workers())