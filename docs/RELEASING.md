# Release Process

This document describes how to create a new release of the eBPF TCP Monitor.

## Prerequisites

- Write access to the repository
- All tests passing on `main` branch
- Changelog/release notes prepared

## Release Steps

### 1. Create a Release on GitHub

1. Go to the [Releases page](https://github.com/rogerwesterbo/ebpf-testing/releases)
2. Click "Draft a new release"
3. Click "Choose a tag" and create a new tag following semantic versioning:

   - Format: `v{MAJOR}.{MINOR}.{PATCH}` (e.g., `v1.2.3`)
   - Use `v` prefix
   - Follow [Semantic Versioning](https://semver.org/):
     - **MAJOR**: Breaking changes
     - **MINOR**: New features (backwards compatible)
     - **PATCH**: Bug fixes (backwards compatible)

4. Set the release title (e.g., `v1.2.3 - Description`)
5. Add release notes describing:

   - **What's New**: New features
   - **Bug Fixes**: Fixed issues
   - **Breaking Changes**: If any (for major versions)
   - **Known Issues**: If any

6. Click "Publish release"

### 2. Automated Release Workflow

Once you publish the release, the [release.yml](.github/workflows/release.yml) workflow automatically:

1. **Builds multi-architecture Docker images** (amd64, arm64, arm/v7)
2. **Pushes images to GitHub Container Registry**:

   - `ghcr.io/rogerwesterbo/ebpf-testing:v{VERSION}`
   - `ghcr.io/rogerwesterbo/ebpf-testing:{MAJOR}.{MINOR}`
   - `ghcr.io/rogerwesterbo/ebpf-testing:{MAJOR}`
   - `ghcr.io/rogerwesterbo/ebpf-testing:latest`

3. **Updates Helm chart** with:

   - Chart version matching the release
   - appVersion matching the release
   - Image tag with digest for immutability

4. **Packages and pushes Helm chart** to OCI registry:

   - `oci://ghcr.io/rogerwesterbo/helm/ebpf-testing`

5. **Creates release binaries** for each architecture:

   - `ebpf-tcp-monitor-amd64.tar.gz`
   - `ebpf-tcp-monitor-arm64.tar.gz`
   - `ebpf-tcp-monitor-arm.tar.gz`

6. **Uploads all artifacts** to the GitHub release

7. **Updates release notes** with installation instructions

### 3. Verify the Release

After the workflow completes (usually 5-10 minutes):

#### Check Docker Images

```bash
# Pull the image
docker pull ghcr.io/rogerwesterbo/ebpf-testing:v1.2.3

# Verify multi-arch
docker manifest inspect ghcr.io/rogerwesterbo/ebpf-testing:v1.2.3
```

#### Check Helm Chart

```bash
# Pull the Helm chart
helm pull oci://ghcr.io/rogerwesterbo/helm/ebpf-testing --version 1.2.3

# Or install directly
helm install ebpf-testing oci://ghcr.io/rogerwesterbo/helm/ebpf-testing --version 1.2.3
```

#### Check Release Assets

Visit the release page and verify:

- ✅ All 3 architecture tarballs are attached
- ✅ Helm chart `.tgz` is attached
- ✅ Installation instructions are added to the release notes

### 4. Announce the Release

After verifying:

- Update any documentation that references version numbers
- Announce in relevant channels (if applicable)
- Update deployment guides if needed

## Troubleshooting

### Workflow Failed

1. Check the [Actions tab](https://github.com/rogerwesterbo/ebpf-testing/actions)
2. Click on the failed workflow run
3. Review the logs for errors
4. Common issues:
   - **Permission denied**: Check repository permissions
   - **Build failed**: Test locally with `make build-cross`
   - **Image push failed**: Verify GHCR permissions

### Fix and Re-run

If the workflow fails:

**Option 1**: Delete and recreate the release

1. Delete the tag: `git push --delete origin v1.2.3`
2. Delete the release on GitHub
3. Create a new release with the same tag

**Option 2**: Re-run the workflow

1. Go to Actions tab
2. Find the failed workflow
3. Click "Re-run all jobs"

### Emergency Rollback

If a release has critical issues:

1. **Create a new patch release** with the fix (e.g., `v1.2.4`)
2. **Update documentation** to recommend the new version
3. **Add a notice** to the problematic release notes

## Release Checklist

Before creating a release:

- [ ] All tests passing on `main` branch
- [ ] CI/CD pipeline green
- [ ] Documentation updated
- [ ] CHANGELOG updated (if you have one)
- [ ] Version bump is appropriate (major/minor/patch)
- [ ] Breaking changes documented (if any)
- [ ] Migration guide prepared (if needed)

After creating a release:

- [ ] Workflow completed successfully
- [ ] Docker images available and working
- [ ] Helm chart available and deployable
- [ ] Release binaries downloadable
- [ ] Installation instructions accurate
- [ ] Announcement made (if applicable)

## Version Strategy

### Development Versions

- `edge` - Latest commit on `main` branch (built by CI)
- `main-{sha}` - Specific commit from `main` branch

### Release Versions

- `v1.2.3` - Specific version
- `v1.2` - Latest patch in 1.2.x series
- `v1` - Latest minor in 1.x.x series
- `latest` - Latest stable release

### Pre-release Versions (Future)

For beta/RC versions, use:

- `v1.2.3-beta.1`
- `v1.2.3-rc.1`

Mark as "pre-release" in GitHub when publishing.

## Helm Chart Versioning

The Helm chart version follows the application version. Both are updated automatically during the release workflow.

### Installing Specific Versions

```bash
# Latest version
helm install ebpf-testing oci://ghcr.io/rogerwesterbo/helm/ebpf-testing

# Specific version
helm install ebpf-testing oci://ghcr.io/rogerwesterbo/helm/ebpf-testing --version 1.2.3

# List available versions
helm search repo ebpf-testing --versions
```

## Additional Resources

- [GitHub Releases Documentation](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [Semantic Versioning](https://semver.org/)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
- [OCI Artifacts](https://helm.sh/docs/topics/registries/)
