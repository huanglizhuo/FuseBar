# FuseBar development

Use codebase-memory-mcp for code discovery. If this project has no graph, run index_repository first. Prefer search_graph, trace_path, get_code_snippet, query_graph and search_code to grep/glob for code symbols. Fall back to rg for literals, config, documentation or insufficient graph results.

Read docs/PLAN.md before changing product scope. Keep data local, native system icons under user control, unknown states explicit, and positions in OrbView stable. No new runtime dependency without a concrete reason.

Build: `zsh Scripts/build.sh`. Test: `zsh Scripts/test.sh`. Regenerate FuseBar.xcodeproj with `xcodegen generate` after adding sources or changing project.yml. Update docs/VALIDATION.md with observed results; don't label simulated screenshots as live hardware verification.

## Release flow

1. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`, run `xcodegen generate`, build and test.
2. Write release notes (default `Distribution/RELEASE_NOTES.md`; pass another file as the second argument).
3. Commit and push the release commit, then run `zsh Scripts/release.sh vX.Y.Z` from a clean tree. The script validates the tag against `MARKETING_VERSION`, then tests, archives, notarizes, exports the stapled Developer ID app, pushes the git tag (which triggers the Action) and creates a **draft** release with the signed ZIP.
4. The tag push automatically triggers `.github/workflows/release.yml` (Actions → Verify and publish release). The Action downloads the draft asset and verifies Developer ID Team `N9Q47Y2LQ4`, bundle ID, version, universal architectures, signature and stapled notarization; only then it attaches `SHA256SUMS.txt` and publishes. `workflow_dispatch` with a tag input is the manual retry path.
5. Full detail lives in `Distribution/README.md`. Never publish an unsigned or un-notarized build to work around a pending notarization.
