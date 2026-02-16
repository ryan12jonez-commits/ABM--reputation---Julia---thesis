# ABM--reputation---Julia---thesis

This repo contains a deliberately simple agent-based model that follows the flowchart:

**Random initialize population → Vote → Evaluate reputation → Update state (Fermi) → Loop** - closest to diagram 

Model a clean, working loop that runs at large N (50,000), uses local (network) interactions, and uses the standard Fermi imitation rule. Once this baseline is stable, I can add truth (for discussion- discussion point at the bottom - perhaps peer), signal accuracy, costs, and strategy types without rebuilding everything.

## What the model does

Agents sit on a fixed social network. Each agent has:
- a binary *Opinion* (0/1), and
- a continuous **reputation* score.

Each timestep runs the same sequence:

1) *Vote (recording step)*
- I compute the current population majority opinion. This is mainly for logging/plots.

2) *Evaluate reputation (local)*
Each agent’s reputation updates based on local agreement/disagreement (via a neighbour interaction), with optional decay so reputation doesn’t blow up.

4) **Update state (Fermi imitation)**
Repeated pairwise comparison events on the network.
An agent is more likely to copy a neighbour’s opinion when the neighbour’s “payoff” is higher.
In the baseline, the payoff proxy is reputation.

Then the model loops.

 minimal scaffold: local structure + endogenous reputation + Fermi updating.

## Fermi rule used

For an update event, a focal agent `B` compares to a neighbour `A`. If their opinions differ, `B` copies `A` with probability:

\[p = \frac{1}{1 + \exp(-\beta(\pi_A - \pi_B))}\] (I have shown equaation - but from best knowledge this how it is coded in Julia).

- \(\beta\) controls how sensitive copying is to payoff differences.
- In this baseline, \(\pi\) is reputation (later it becomes an actual payoff).


## Network

Right now the default is an Erdős–Rényi random graph with expected degree `k`:

- edge probability is set to \(p = k/(N-1)\) so average degree stays about constant as N grows.

Later I’ll swap the graph generator to small-world (source at the bottom) / scale-free to test how clustering and hubs change outcomes - or perhaps .


## Outputs (what I plot/save)

The script records:
- fraction of opinion = 1 over time,
- consensus level over time (majority share),
- mean reputation over time,
- final opinion counts and final reputation histogram.

These outputs are mainly a sanity check, the model runs, parameters/topology matter in the expected direction, and the loop behaves predictably.

## How this connects to the real research question (next step)

The minimal extension to get closer to the real question is:

- add agent type `Scout` vs `Sprinter`,
- add a binary “truth” state each period,
- give scouts higher signal accuracy but charge them a cost \(c\),
- update reputation based on verified correctness (not agreement),
- define payoff \(\pi_i = r \cdot reputation_i - c \cdot 1\{Scout\}\),
- run Fermi copying over strategy type (Scout/Sprinter) while holding \(\beta\) fixed and sweeping \(r\).

That’s the point where “minimum r” becomes meaningful.


