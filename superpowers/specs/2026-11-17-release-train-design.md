# Release train: the umbrella releases prod

Date: 2026-11-17. Status: approved (chat), building.

## Problem

Prod followed the highest `X.Y.Z` tag of each component repo through Argo CD
Image Updater. Each repo released on its own, so prod could run server 0.4
with console 0.3, and nothing recorded which set prod ran. The umbrella's
submodule pointers decided nothing about deployment. GHCR also kept every
`sha-<commit>` image of every push to `main` forever.

## Decision

The umbrella is the unit of a prod release. Dev is unchanged.

- dev: each repo's push to `main` builds `:main` and `:sha-<commit>`; Image
  Updater moves `stack-dev` and `ai-dev` by the digest of `:main`.
- prod: no Image Updater. `stack-prod` and `ai-prod` run exactly what the
  umbrella names:
  - `infra/argocd/stacks.yaml`: `stack-prod` has `targetRevision: vX.Y.Z`,
    the umbrella's release tag, so the chart and `values-prod.yaml` are those
    of the release.
  - `infra/stack/values-prod.yaml`: `images.{server,website,docs,console,agent}.tag: X.Y.Z`.
  - `infra/argocd/ai.yaml`: `ai-prod` has `targetRevision: <ai submodule commit>`
    and `images.models.tag: X.Y.Z`.
- A release is the umbrella workflow `release.yml`, run by hand with a
  version. It reads each submodule's commit at `main`, checks that
  `ghcr.io/shopnexus/<repo>:sha-<commit>` exists, adds the tag `X.Y.Z` to it
  (`docker buildx imagetools create`, no rebuild), writes the three files
  above, commits "release X.Y.Z" on `main`, tags that commit `vX.Y.Z` and
  pushes both. Root applies the Application changes from `main`; stack-prod
  then syncs the tag.
- Preparing a release is bumping the submodules in the umbrella to the
  commits dev has run, which gives the pointers a meaning.
- Rollback: revert the release commit on `main`. Both Applications go back
  to the previous release's tag and commit.
- The component repos lose their `release` job (tag `vX.Y.Z` per repo); a
  repo tag no longer reaches prod.

## Image retention

Each component repo's `build.yml` gets a `cleanup` job after `build`, with
`dataaxiom/ghcr-cleanup-action` v1.2.2: keep `main` and every `X.Y.Z`
(`exclude-tags`), keep the 10 newest other tagged images (`sha-*`), delete
untagged and partial images. Every image prod runs has an `X.Y.Z` tag, so
cleanup never removes it. A release must name a commit among the 10 newest
builds of each repo, or the workflow fails on the missing `sha-<commit>`.

## Access

The workflow's `GITHUB_TOKEN` writes the six packages only when each package
grants the umbrella repository write access (package settings, Manage Actions
access). That is a one-time step in the GitHub UI per package.

## Checks

`infra/check.sh`: stack-prod's `targetRevision` is `v` plus the version in
every `images.*.tag` of `values-prod.yaml` and `ai-prod`'s
`images.models.tag`; `ai-prod`'s `targetRevision` is a 40-character commit;
the ImageUpdater has entries for `stack-dev` and `ai-dev` only.

## Bootstrap

Before the first release, the files name `0.1.0`, tag `v0.1.0` and the
current ai commit; `v0.1.0` does not exist yet, so prod is not deployable
until the first run of `release.yml`. No prod stack runs today.
