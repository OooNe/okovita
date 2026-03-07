# Okovita Architecture & Guidelines

## Agent Testing Guidelines
- **Always** create disposable or quick test scripts (e.g. `test_*.exs`, `*.py`) inside the `.agent_tests/` directory instead of the project root. This directory is ignored by Git and prevents cluttering the main repository.
