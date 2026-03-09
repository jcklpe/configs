# Configs Improvements TODO
### Documentation
- [x] Update README.md with current install process
- [x] Document which modules work in bash vs zsh vs both
- [x] Add troubleshooting section for common issues (like the VS Code terminal integration)
- [x] Document the WSL-specific configuration

## Future/Low Priority

### Shell Cleanup
- [ ] Convert `movement/movement.sh` to a pure bash-compatible file: remove any zsh-specific syntax (`setopt`, `autoload`, `compdef`). Also revisit the `ls`→`eza` alias — aliasing `ls` breaks default shell scripts; the new `go` function is the right replacement and should fully take over.
- [ ] Research actively-maintained alternatives to the `bit` CLI git helper (e.g. `gitui`, `lazygit`, `tig`) — removed `bit` completion from bashrc since it had a hardcoded Intel Mac path and unknown provenance.

### VS Code configuration improvements
- [ ] Review vscode/ folder contents and update/remove outdated configs (snippets, settings, etc.)
- [ ] Investigate alternatives to custom background extension (previously used, now unsupported)
- [ ] Research VS Code settings sync alternatives (exit strategy from GitHub/Microsoft ecosystem)

## Notes
- Keep separate install scripts per OS (mac-install.sh, linux-install.sh) - this is fine
- CONFIGS hardcoded to ~/configs is acceptable, but auto-detect is still useful for edge cases
- Don't need extensive logging/error handling - keep it simple