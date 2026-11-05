# Stage 5 — Make the viewer accurately explain the lab state

Follow the [shared instructions](README.md#instructions-shared-by-every-prompt).
Prerequisite: stage 4's implemented API and authorization contract.

Revise the existing lightweight viewer to make baseline connectivity, locked
authorization, unavailable infrastructure, and Vault-authorized data visibly
distinct. Keep the workshop focused on learning; avoid a framework rewrite unless
the existing implementation prevents a concrete requirement.

Requirements:

- Treat `health.unlocked` as the authority. Never infer authorization solely from
  a channel name or render environment access as successful Vault completion.
- Show useful DB/API readiness and credential-source information without exposing
  secrets or detailed internal stack traces.
- Fetch/render the canonical item shape in stable order; derive the puzzle reveal
  from authorized returned data and clear stale rows/reveal on lock or failure.
- Explain baseline mode explicitly. Do not make a cosmetic persona selector stand
  in for real Vault authentication; persona exercises use the actual supported flow.
- Establish a dedicated public assets directory and one runtime config source.
  Do not expose package manifests, server source, private runtime files, or state.
- Keep editable API URLs if useful, with validation and clear reset behavior.
  Distinguish browser-host URLs from internal Podman addresses.
- Use safe DOM rendering for every field, accessible labels/status feedback,
  keyboard navigation, narrow layouts, and reduced-motion support. Refresh shortcuts
  must not intercept ordinary typing inside inputs.
- Preserve a small, understandable frontend that participants can inspect.

Check authorized, baseline, locked, DB-unavailable, and network-error states.
Exercise transitions so a previously displayed dataset does not remain visible
after an authorization failure. Verify escaping using representative hostile field
values, keyboard input, config precedence, and static-file exposure boundaries.
Capture browser evidence when available and record exactly what was tested under
AC-07/09/10/11/13. Do not claim visual/browser checks from source inspection alone.
