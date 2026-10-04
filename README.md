# AES official flight computers

Official flight computer definitions for the AES gateway (`aesgw2`).

Each directory holding a `definition.json` is one flight computer; its ID is the
directory path relative to the repo root (e.g. `A320/MCDU`).

The gateway ships the tag pinned in its `OFFICIAL_FC_REF` and can sync newer
tags at runtime (or import a release tarball on air-gapped sites). Official
definitions are read-only in the gateway; customizing one copies it into the
site's private library.

Releases are plain git tags (`vX.Y.Z`); the gateway consumes GitHub's source
tarball for the tag.
