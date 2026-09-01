# Dependency maintenance

Dependabot proposes monthly version updates without any maintainer-managed
token or secret and without AWS identity, approval, or merge capability. It
covers the dependency formats that GitHub supports directly:

- GitHub Actions in `.github/workflows`, retaining full commit-SHA references
  and updating their same-line release comments;
- OpenTofu providers and registry modules in every root and reusable module,
  including provider checksums in committed lockfiles; and
- public Nix flake inputs recorded in `flake.lock`.

Updates are grouped by ecosystem and limited to one open version-update pull
request per ecosystem. Dependabot never auto-approves, auto-merges, or applies
infrastructure. The repository's own pinned reusable planning-workflow reference
is excluded because changing it is part of the AWS trust bootstrap, not routine
dependency maintenance.

## Review and promotion

Treat every Dependabot pull request as an untrusted proposal. It receives only
offline checks, and the required aggregate check intentionally fails. The bot
cannot obtain an AWS OIDC session or an Actions secret, and its branch cannot be
merged through the protected `main` ruleset.

After reviewing the upstream release notes, immutable Action commit, generated
lockfile changes, and complete diff, promote the proposal to a maintainer-owned
branch:

```bash
gh pr checkout <dependabot-pr-number>
git switch -c chore/deps-<topic>
git push -u origin HEAD
gh pr create --base main --fill
```

Link the replacement pull request to the Dependabot proposal. The new pull
request must run the complete offline suite and all four trusted read-only plans.
Review its plan comment normally; do not merge an unexpected provider, module,
state, IAM, account, or workflow change. Merging protected `main` remains the
only event that starts the ordered AWS applies, while `terraform/github` remains
manual.

For a Nix-only update, also enter the updated development shell and run the
normal local suite before merge:

```bash
nix develop
just validate
```

## Manually maintained versions

Dependabot does not parse every pinned tool surface in this repository. Update
these together in an ordinary maintainer pull request when needed:

- `.opentofu-version` and the `OPENTOFU_VERSION` workflow values;
- TFLint and its AWS ruleset version;
- the downloaded `actionlint` and ShellCheck versions and checksums; and
- any pinned ref written directly in `flake.nix` rather than resolved through
  `flake.lock`.

The committed OpenTofu lockfiles are authoritative. Never regenerate or accept
them with an unreviewed provider source, unexpected provider, or unexplained
checksum removal.

## Suspected dependency compromise

Do not promote or merge a suspicious update. Close the proposal and temporarily
ignore the affected version if Dependabot repeatedly recreates it. If a suspect
version reached `main`, disable the affected workflow, replace or revert the
dependency through a reviewed maintainer pull request, and inspect the relevant
GitHub Actions logs and AWS audit history. OIDC creates no stored cloud key, but
any unexpected session or infrastructure action still requires investigation
before the workflow is re-enabled.
