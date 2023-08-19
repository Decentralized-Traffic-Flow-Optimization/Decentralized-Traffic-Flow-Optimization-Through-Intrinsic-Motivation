
using Random, Statistics, Plots
###Parameters ####
#R: road vector with cars (-1: empty cell, +ve integer: car)
#L: road length
#N: number of cars
#vₘ: maximum velocity allowed
#ρ: density
#p_brake : braking probability
################################
function NaSch_road(L :: Int64, ρ:: Float64 , vₘ)
    #Road initialization
    N=Int(round(L*ρ))
    v=Int64[]
    v=rand(1:vₘ, N)
    R=vcat(v, fill(-1,L-N))
    shuffle!(R)
    R, N
end
function accelerate( L :: Int64, R :: Vector{Int64}, vₘ :: Int64)
    #NaSch Rule1
    R_c=copy(R)
    @inbounds @simd for i=1:L
        if R_c[i]> -1 && R_c[i] < vₘ
            R_c[i]+=1
        end
    end
    R_c
end

function breaking(L :: Int64, R :: Vector{Int64})
    #NaSch Rule2
    for i in 1:L
        if R[i] > -1
            for k in (i+1):(i+R[i])
                if k <= L
                    if R[k] ≠ -1
                        R[i] = k-i-1
                        break
                    end
                elseif k > L
                    if R[k%L] ≠ -1
                        R[i] = L+((k%L)-i-1)
                        break
                    end
                end
            end
        end
    end
    R
end

function random_breaking(L :: Int64, R :: Vector{Int64}, p_brake :: Float64)
    #NaSch Rule3
    @inbounds for i in 1:L
        if R[i] ≠ -1 && R[i] ≠ -2 && R[i] ≠ 0
            if rand() ≤ p_brake
                R[i] -=1
            end
        end
    end
    R
end
function displace(L :: Int64, R :: Vector{Int64})
    #NaSch Rule4
    R_c= copy(R)
    @inbounds for i in 1:L
        if R_c[i] ≠ -1 && R_c[i] ≠ 0
            if i+R_c[i] > L
                R[(i+R_c[i])%L]= R_c[i]
                R[i]=-1
            else
                R[i+R_c[i]]=R_c[i]
                R[i]=-1
            end
        end
    end
    R
end

function space_avg_velocity(R :: Vector{Int64} )
    ##1/L(sum(v))##
    v=Int64[]
    L=size(R)[1]
    for i in 1:L
        if R[i] ≥ 0
            push!(v,R[i])
        elseif R[i] == -1
            push!(v,0)
        end
    end
    v_avg=sum(v)/L
    v_avg
end


function traffic_flow_no_agent(L :: Int64, R :: Vector{Int64},  vₘ :: Int64, p_brake :: Float64, T :: Int64 )
    ##calculate traffic flow on NaSch road without any agents##
    R_c= copy(R)
    F_v=0.0
    sim = zeros(Int, T, L)
    v_avgs=[]
    for t in 1:T
        R_c= accelerate(L, R_c, vₘ)
        R_c= breaking(L, R_c)
        R_c= random_breaking(L, R_c, p_brake)
        R_c= displace(L, R_c)
        if t ≥1000 & t%5==0
            v=space_avg_velocity(R_c)
            push!(v_avgs, v)
        end
        sim[t, :] = [j == -1 ? 0 : 1 for j in R_c]
    end
    F_v= sum(v_avgs)/size(v_avgs)[1]
    F_v, sim
    
end
