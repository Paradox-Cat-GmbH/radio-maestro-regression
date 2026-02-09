# About RadioRegression

Name: RadioRegression (radio-maestro-regression)

Purpose: A Maestro-driven regression test suite for radio features. It combines UI-driven flows (Maestro YAML) with ADB-based validations to verify that radio functionality is working end-to-end — not just visually, but by confirming audio focus and active media sessions.

Contents:
- `flows/` — YAML test flows (demo and regression).
- `scripts/` — helpers and runners (action injection, verification, suite runners).
- `.maestro/` — Maestro configuration (local test output settings).
- `artifacts/` — generated test outputs (screenshots, videos, logs). This path is excluded from Git by `.gitignore`.

How to use:
- Run demo flows: `run_demo_suite.bat`
- Run full suite: `run_suite.bat`
- Inject single actions: `scripts\run_action.bat <type> <action>` (examples in README)

Who should use this repo: QA engineers, automation engineers, and maintainers who run and author Maestro flows for radio E2E validation.

Recommended next steps:
- Add collaborators and set repo permissions on GitHub.
- Add `CONTRIBUTING.md` describing flow conventions and how to run tests locally.
- Add CI (GitHub Actions) for lightweight smoke tests and lint checks.
- Add issue templates to classify infra vs test failures.
