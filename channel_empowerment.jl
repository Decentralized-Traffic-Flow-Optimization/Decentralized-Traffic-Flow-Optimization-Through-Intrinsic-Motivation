
using StatsBase, DataStructures, Plots, Statistics
include("NaSch_model.jl")
floatType = Float64

###Parameters ####
#R: road vector with cars (-1: empty cell, +ve integer: car)
#L: road length
#N: number of cars
#vₘ= maximum velocity allowed
#x, xₙ :position of agent and leading car on the road respectively
#vₐ, vₙ: velocity of agent and leading car on the road respectively
#Δ: Distance between agent and leading car.
#s₀: initial State
#s: state
#Tₕ: empowerment horizon
#T: Sampling time
#Pv: transsition probabilities of velocities of normal cars P(v(t+1)|v(t))
##################################################


T = 1e3

function delta_max(s::Tuple{Int64, Int64}, Tₕ:: Int64, vₘ::Int64)
	####calculate the maximum delta  that can e obtained for Tₕ tme steps######
    function step(s::Tuple{Int64, Int64})
        Δ, v = s
        v′ₘ=v+1>vₘ ? vₘ : v+1
        A=0
        Δ′ₘ= Δ+v′ₘ-A
        Δ′ₘ, v′ₘ
    end

    for t in 1:Tₕ
        s′=step(s)
        s=s′
    end
     s[1]

end


function oneStep(s::Tuple, a::Int, Pv::Array{floatType, 2})
	#####one step update##########
	Δ, v = s
	aR= (0:v+1) > (0:vₘ) ? (0: vₘ) : (0:v+1)
	v′   = sample(aR, Weights(Pv[v+1, :]))
	vₐ   = a > Δ + v′ ? Δ + v′ : a
	Δ′ = Δ + v′ - vₐ
	Δ′, v′
end

function channel_nstep(s₀::Tuple, A, Pv::Array{floatType, 2}, Tₕ::Int64, vₘ::Int64)

	### Tₕ step channel for  ###
	Δₘ = delta_max(s₀,Tₕ, vₘ )
	P = 1e-12ones(floatType, length(A), Δₘ+1, vₘ+1)
	for (i, a) in enumerate(A)
		s = s₀
		for t in 1:T
			for i in 1:Tₕ
                s = oneStep(s, a.I[i], Pv)
            end
			P[i, (s .+ 1)...] += 1
			s = s₀
		end
	end
	#normalize
	sum_P= sum(P, dims=(2,3))
	Pₙ= P./sum_P
	Pₙ	
end

function channel_1step(s₀::Tuple, A, Pv::Array{floatType, 2})

	### channel for 1 step actions ###
	Δ, vₙ = s₀
	Δₘ = (Δ+(vₙ+1))> (Δ+5) ? (Δ+5) : (Δ+(vₙ+1)) 
	P = 1e-12ones(floatType, length(A), Δₘ+1, vₘ+1)
	for (i, a) in enumerate(A)
		s = s₀
		for t in 1:T
			s = oneStep(s, a, Pv)
			P[i, (s .+ 1)...] += 1
			s = s₀
		end
	end
	### normalize ###
	sum_P= sum(P, dims=(2,3))
	P₁= P./sum_P
	P₁

end

function Empowerment(P::Array{floatType, 3})
	####calculate channel capacity using Blahut-Arimoto Algorithm ########

	### mutual infor ###
	MI(Pyx, Py, Px) = sum(log.( (Pyx ./ (Py .* Px)) .^ Pyx))[1]

	### policy ###
	Pa_s = (Ps_a = rand(size(P)[1], 1, 1); Ps_a = Ps_a ./ sum(Ps_a, dims=1))
	C = []
	T= 70
	for i in 1:T
		### inverse channel update ###
		Qs_a = ( q = P .* Ps_a; q ./ sum(q, dims=1) )
		### policy update ###
		Ps_a = ( p = exp.( sum(P .* log.(Qs_a), dims=(2, 3))); p ./ sum(p, dims=1))
		### information update for monitoring###
		Pyx = P .* Ps_a
		Py  = sum(Pyx, dims=(2, 3))
		Px  = sum(Pyx, dims=1)
		push!(C, MI(Pyx, Py, Px))
	end
	Ps_a, C
end

function Delta_agent(L::Int64, R :: Vector{Int64}, x::Int64, N::Int64)
	###calculate position and distance to leading car###########
	if N == 1
		xₙ = x
		Δ = L-1
	else
		for j in x+1 : L+L
			if j ≤ L
				if R[j] ≥ 0
					xₙ= j
					break
				end	
			#Check for periodic boundary condition#
			elseif j> L
				if R[j%L] ≥ 0
					xₙ = j%L
					break
				end
			end
		end
		if xₙ > x
			Δ= (xₙ-x)-1
		elseif xₙ < x
			Δ= (L-x+xₙ)-1
		end
	end	
	Δ, xₙ
end

function Action_sequences(vₐ::Int64, Tₕ::Int64)
	#####calculate available Tₕ steps action sequences######
	##action at any time step should be increase by 1 unit and can be decreased by any arbitary amount-> a(t+1)=0:min(a(t)+1,vₘ) 
    action_sequences = [] 
    for t in 1:Tₕ
        aR = (0:vₐ+t) > (0:vₘ) ? (0:vₘ) : (0:vₐ+t)
        push!(action_sequences, aR)
    end
    a=tuple(action_sequences...)
    
    function filter_action_sequence(a)
        for i in 2:Tₕ
            if !(a.I[i] ≤ a.I[i-1] + 1)
                return false
            end
        end
        return true
    end
    
    filter(filter_action_sequence, CartesianIndices(a))
    
end

function Empowerment_action(L::Int64, R::Vector{Int64}, N::Int64, x::Int64, vₘ::Int64, Pᵥ::Array{floatType, 2}, Tₕ::Int64 )
	####calculte expected empowerment#######
	Δ, xₙ = Delta_agent(L, R, x, N)
	vₐ=R[x]
	vₙ=R[xₙ]
	s₀= Δ, vₙ
	#1-step action sequence#
	A= 0: min(vₐ+1, vₘ)
	P₁ =  channel_1step(s₀, A, Pᵥ)
	indices= findall(k -> k> 1e-12, P₁)
	E_a=zeros(floatType, length(A))
	##calculate empowerment of all 1-step future states resulted from 1 step actions####
	for s in indices
		a= s.I[1]-1
		s₁= (s.I[2]-1, s.I[3]-1)
		A_prime= Action_sequences(a, Tₕ)
		C= channel_nstep(s₁, A_prime, Pᵥ,Tₕ, vₘ)
		P_a, E_s= Empowerment(C)
		#expected empowerement
		E_a[s.I[1]]+= P₁[s.I[1], s.I[2], s.I[3]] * E_s[end]
	end
	#select action
	a_select= argmax(E_a)-1
	a_select, E_a

end
