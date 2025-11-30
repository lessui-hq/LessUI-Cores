# Core Update Changelogs

This directory contains automatically generated changelogs for core updates.

## Format

Each file is named: `YYYYMMDD-HHMMSS-{architecture}.md`

For example: `20251130-134719-arm64.md`

## Contents

Each changelog includes:
- **Update summary** - Old and new commit SHAs
- **GitHub compare link** - Direct link to see all changes
- **Commit messages** - Filtered list of commits between versions
  - Merge commits are excluded
  - CI/chore commits are excluded
  - Documentation-only updates are excluded

## Usage

These changelogs are automatically generated when you run:
```bash
make update-recipes-arm64
make update-recipes-arm32
make update-recipes-all
```

They provide a permanent record of what changed in each update, making it easy to:
- Review what's new in updated cores
- Troubleshoot issues introduced by updates
- Track the evolution of cores over time
