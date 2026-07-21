# Security policy

## Scope

ChaosGun is a local/offline game prototype. It does not require a backend, database, or API key to run.

## Reporting a suspected secret

Please do not open a public issue containing credentials, personal data, or private infrastructure details. Contact the repository owner privately and include the affected file or commit without reproducing the secret.

If a credential is found, revoke or rotate it first, then remove it from the working tree and Git history before publishing a repository.

## Local credentials

The optional Blender MCP integration reads `RODIN_FREE_TRIAL_KEY` from the local environment. Real values must never be committed, pasted into issues, or included in screenshots.
