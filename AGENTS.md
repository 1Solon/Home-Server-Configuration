# Removing / Archiving Old Applications

When asked to remove or archive an old application, move the application's manifests to `archive/` directory using `git mv`.

# Flux and State

This is a Flux backed repository, as such, pushing to the repository will trigger a Flux reconciliation, affecting the cluster. You should never do this without permission.

Only manually patch kubernetes resources for testing, or verification, as your changes will be overwritten by Flux.
