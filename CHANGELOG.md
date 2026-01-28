# Changelog

## 2026-01-27

- Home page: keep testimonial links clickable while skipping keyboard focus (#18, thanks @wilfriedladenhauf).

## 2026-01-16

- `install.sh`: warn when the user’s original shell `PATH` likely won’t find the installed `clawdbot` binary (common Node/npm global bin issues); link to docs.
- CI: add lightweight unit tests for `install.sh` path resolution.
