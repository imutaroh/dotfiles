# pstack model configuration. One line per role. Delete a line to fall back to the skill default.
# `inherit-parent` or `auto` as a value: the role runs on the parent chat model (omit Agent `model`). Alias entries in a panel list still count toward its fan-out.
# Claude Code: a value `<model> <effort>` maps to Agent `model` and `effort`. Gemini seats have no Claude Code equivalent, so they are `inherit-parent`.
# defaults: 3
# budget: medium (high)
feature, refactoring: opus high
bug-fix: opus high
perf-issue: opus high
hillclimb: opus high
judgment and prose: opus high
arena runners: fable medium, opus medium, inherit-parent
arena cross-judge pool: opus medium, inherit-parent
swarm workers: opus medium
interrogate reviewers: fable medium, opus medium, inherit-parent
