# MergeBar development

Use codebase-memory-mcp for code discovery. If this project has no graph, run index_repository first. Prefer search_graph, trace_path, get_code_snippet, query_graph and search_code to grep/glob for code symbols. Fall back to rg for literals, config, documentation or insufficient graph results.

Read docs/PLAN.md before changing product scope. Keep data local, native system icons under user control, unknown states explicit, and positions in OrbView stable. No new runtime dependency without a concrete reason.

Build: `zsh Scripts/build.sh`. Test: `zsh Scripts/test.sh`. Regenerate MergeBar.xcodeproj with `xcodegen generate` after adding sources or changing project.yml. Update docs/VALIDATION.md with observed results; don't label simulated screenshots as live hardware verification.
