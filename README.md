# ABM--reputation---Julia---thesis

This repo contains a deliberately simple agent-based model that follows the flowchart:

**Random initialize population → Vote → Evaluate reputation → Update state (Fermi) → Loop**

The point of this version is not to answer the full “scouts vs sprinters / information cost” question yet. The point is to get a clean, working loop that runs at large N, uses local (network) interactions, and uses the standard Fermi imitation rule. Once this baseline is stable, I can add truth, signal accuracy, costs, and strategy types without rebuilding everything.


## What the model does

Agents sit on a fixed social network. Each agent has:
- a binary **opinion** (0/1), and
- a continuous **reputation** score.

Each timestep runs the same sequence:

1) **Vote (recording step)**
- I compute the current population majority opinion. This is mainly for logging/plots.

2) **Evaluate reputation (local)**
- Each agent’s reputation updates based on local agreement/disagreement (via a neighbour interaction), with optional decay so reputation doesn’t blow up.

3) **Update state (Fermi imitation)**
- Repeated pairwise comparison events on the network.
- An agent is more likely to copy a neighbour’s opinion when the neighbour’s “payoff” is higher.
- In the baseline, the payoff proxy is reputation.

Then the model loops.

This is meant as a minimal scaffold: local structure + endogenous reputation + Fermi updating.

---

## Fermi rule used

For an update event, a focal agent `B` compares to a neighbour `A`. If their opinions differ, `B` copies `A` with probability:

\[
p = \frac{1}{1 + \exp(-\beta(\pi_A - \pi_B))}
\]

- \(\beta\) controls how sensitive copying is to payoff differences.
- In this baseline, \(\pi\) is reputation (later it becomes an actual payoff).

This is the standard pairwise-comparison / “Fermi” update used in evolutionary dynamics.

---

## Network

Right now the default is an Erdős–Rényi random graph with expected degree `k`:

- edge probability is set to \(p = k/(N-1)\) so average degree stays about constant as N grows.

Later I’ll swap the graph generator to small-world / scale-free to test how clustering and hubs change outcomes.

---

## Outputs (what I plot/save)

The script records:
- fraction of opinion = 1 over time,
- consensus level over time (majority share),
- mean reputation over time,
- final opinion counts and final reputation histogram.

These outputs are mainly a sanity check: the model runs, parameters/topology matter in the expected direction, and the loop behaves predictably.

---

## What this baseline is NOT claiming

This version does **not** include:
- a “true” state of the world,
- signal accuracy,
- information costs,
- scouts vs sprinters as distinct strategy types,
- reputation tied to verified correctness.

So the results here should be read as properties of a local imitation process with an endogenous influence score — not as a claim about epistemic performance yet.

---

## How this connects to the real research question (next step)

My main question (later model) is:

**Under a Fermi-imitation dynamic, what minimum reputational reward is required for scouts (or whatever agent) (who pay an information cost) to invade and persist among sprinters?**

This baseline already has the two core pieces needed for that:
1) **local structure (network interactions)**, and
2) **Fermi imitation based on payoff differences**.

The minimal extension to get closer to the real question is:

- add agent type `Scout` vs `Sprinter`,
- add a binary “truth” state each period,
- give scouts higher signal accuracy but charge them a cost \(c\),
- update reputation based on verified correctness (not agreement),
- define payoff \(\pi_i = r \cdot reputation_i - c \cdot 1\{Scout\}\),
- run Fermi copying over strategy type (Scout/Sprinter) while holding \(\beta\) fixed and sweeping \(r\).

That’s the point where “minimum r” becomes meaningful.

---

