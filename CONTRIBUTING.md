# Contributing

Thank you for contributing to RadioRegression. This repository contains Maestro flows and small helper scripts used for radio regression testing.

Quick guide
- Author flows under `flows/` using the existing naming and structure.
- Use `scripts/run_flow_with_actions.py` or the `.bat` runners to execute flows locally.
- Do not commit generated artifacts (screenshots, videos). They should go to `artifacts/` which is ignored.

Pull requests
- Create a branch per feature/fix: `feature/<short-desc>` or `fix/<short-desc>`.
- Include a short description and relevant environment details in the PR.
- Add a link to any Maestro Studio screenshots or logs if the flow relies on specific selectors.

Style
- YAML flows should be UTF-8 and use consistent indentation (2 spaces preferred).
- Keep steps small and focused; prefer subflows for repeated actions.
