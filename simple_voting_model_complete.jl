# simple_voting_localrep_largeN.jl
# Flowchart ABM: Initialize -> Vote -> Evaluate reputation (LOCAL) -> Fermi -> Loop
# Robust on Agents.jl versions where model.<x> routes through the properties Dict.
# Key rule: never use model.space or model.properties (use getfield).

using Agents
using Graphs
using Statistics
using Random
using Plots

# ============================================================
# 1) Agent
# ============================================================

@agent struct Voter(GraphAgent)
    opinion::Int
    reputation::Float64
end

# ============================================================
# 2) Initialize (blue box)
# ============================================================

function initialize_model(n_agents::Int; k::Int=10, seed::Int=1)
    rng = MersenneTwister(seed)

    # Sparse ER with ~constant average degree k
    p_edge = k / (n_agents - 1)
    g = erdos_renyi(n_agents, p_edge)
    space = GraphSpace(g)

    props = Dict{Symbol, Any}(
        :step_count => 0,
        :record_every => 5,                 # change to 1 for small N, 5/10 for big N
        :t_history => Int[],
        :opinion_history => Float64[],      # fraction opinion==1
        :consensus_history => Float64[],    # majority share
        :reputation_history => Float64[],   # mean reputation
        :vote_outcome_history => Int[]      # global vote outcome (0/1), just for reporting
    )

    agent_step!(agent, model) = nothing     # all logic in model_step!

    model = StandardABM(
        Voter, space;
        agent_step! = agent_step!,
        model_step! = model_step!,
        properties = props,
        rng = rng
    )

    # One agent per node; enforce id == pos == node index
    for id in 1:n_agents
        add_agent_own_pos!(Voter(id, id, rand(rng, 0:1), 1.0), model)
    end

    return model
end

# ============================================================
# 3) Vote (green box)
# ============================================================
# Interpretation: everyone "votes" by revealing their current opinion.
# We compute the global majority outcome mainly for logging/plots.

function vote_phase(model)
    s = 0
    n = 0
    for a in allagents(model)
        s += a.opinion
        n += 1
    end

    if s > n ÷ 2
        return 1
    elseif s < n ÷ 2
        return 0
    else
        return rand(abmrng(model), 0:1)  # tie-break
    end
end

# ============================================================
# 4) Fast neighbor sampling (utility)
# ============================================================

function random_neighbor_agent(agent, model)
    space = getfield(model, :space)
    g = getfield(space, :graph)

    neigh_nodes = neighbors(g, agent.pos)
    isempty(neigh_nodes) && return nothing

    nid = rand(abmrng(model), neigh_nodes)
    return model[nid]
end

# ============================================================
# 5) Evaluate reputation (orange box) — LOCAL reputation
# ============================================================
# Minimal local mechanism:
# - reputations decay a bit each tick (λ)
# - each agent samples one neighbour
# - agreement -> +δ, disagreement -> -δ
# This avoids the trivial global runaway you were seeing.

function reputation_phase!(model; δ=0.02, λ=0.01, rmin=0.0, rmax=5.0)
    for a in allagents(model)
        a.reputation = (1 - λ) * a.reputation

        nb = random_neighbor_agent(a, model)
        isnothing(nb) && continue

        a.reputation += (a.opinion == nb.opinion) ? δ : -δ
        a.reputation = clamp(a.reputation, rmin, rmax)
    end
end

# ============================================================
# 6) Update state (purple box) — Fermi rule
# ============================================================
# Pairwise comparison:
# choose focal B, choose neighbour A, adopt A's opinion with
# p = 1 / (1 + exp(-β(πA - πB)))

function fermi_phase!(model; β=1.0)
    rng = abmrng(model)
    N = nagents(model)

    for _ in 1:N
        id = rand(rng, 1:N)
        B = model[id]
        A = random_neighbor_agent(B, model)
        isnothing(A) && continue
        B.opinion == A.opinion && continue

        πA = A.reputation
        πB = B.reputation
        p  = 1.0 / (1.0 + exp(-β * (πA - πB)))

        if rand(rng) < p
            B.opinion = A.opinion
        end
    end
end

# ============================================================
# 7) One flowchart loop per tick
# ============================================================

function model_step!(model)
    P = getfield(model, :properties)
    P[:step_count] += 1
    step = P[:step_count]

    # Vote (global majority) — for logging
    outcome = vote_phase(model)

    # Evaluate reputation — LOCAL rule
    reputation_phase!(model)

    # Update state — Fermi
    fermi_phase!(model)

    # Record (downsample for large N)
    rec = P[:record_every]
    if step % rec == 0
        # fraction of 1s
        ones = 0
        total = 0
        reps_sum = 0.0

        for a in allagents(model)
            ones += a.opinion
            total += 1
            reps_sum += a.reputation
        end

        f1 = ones / total
        cons = max(f1, 1 - f1)
        mean_rep = reps_sum / total

        push!(P[:t_history], step)
        push!(P[:opinion_history], f1)
        push!(P[:consensus_history], cons)
        push!(P[:reputation_history], mean_rep)
        push!(P[:vote_outcome_history], outcome)
    end
end

# ============================================================
# 8) Plots
# ============================================================

function plot_timeseries(model)
    P = getfield(model, :properties)

    t  = P[:t_history]
    oh = P[:opinion_history]
    ch = P[:consensus_history]
    rh = P[:reputation_history]

    p1 = plot(t, oh, xlabel="t", ylabel="fraction opinion=1", legend=false, title="Opinion share")
    p2 = plot(t, ch, xlabel="t", ylabel="majority share", legend=false, title="Consensus", ylims=(0.5, 1.0))
    p3 = plot(t, rh, xlabel="t", ylabel="mean reputation", legend=false, title="Mean reputation")

    plot(p1, p2, p3, layout=(3,1), size=(900,800))
end

function plot_final_distributions(model)
    opinions = [a.opinion for a in allagents(model)]
    reps     = [a.reputation for a in allagents(model)]

    # cleaner than histogram bins=2 for binary data
    p1 = bar(["0","1"], [count(==(0), opinions), count(==(1), opinions)],
             xlabel="opinion", ylabel="count", legend=false, title="Final opinions")

    p2 = histogram(reps, bins=30, xlabel="reputation", ylabel="count",
                   legend=false, title="Final reputations")

    plot(p1, p2, layout=(1,2), size=(900,350))
end

# ============================================================
# 9) USAGE (bottom)
# ============================================================

n_agents = 50_000
n_steps  = 200
k        = 10
seed     = 1

println("Creating model: $n_agents agents, $n_steps steps, k=$k")
model = initialize_model(n_agents; k=k, seed=seed)

# For large runs, set 5 or 10; for small runs set 1
getfield(model, :properties)[:record_every] = 5

opinions0 = [a.opinion for a in allagents(model)]
println("Initial: Opinion 0: $(count(==(0), opinions0)), Opinion 1: $(count(==(1), opinions0))")

run!(model, n_steps)

opinions = [a.opinion for a in allagents(model)]
reps     = [a.reputation for a in allagents(model)]
cons     = max(mean(opinions), 1 - mean(opinions))

println("Final: Opinion 0: $(count(==(0), opinions)), Opinion 1: $(count(==(1), opinions))")
println("Avg reputation: $(round(mean(reps), digits=3)), Range: $(round(minimum(reps), digits=3))-$(round(maximum(reps), digits=3))")
println("Consensus: $(round(cons*100, digits=1))%")

pA = plot_timeseries(model); display(pA)
pB = plot_final_distributions(model); display(pB)
savefig(pA, "timeseries.png")
savefig(pB, "final_distributions.png")
println("Saved: timeseries.png, final_distributions.png")