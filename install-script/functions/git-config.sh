#!/bin/bash
##- Git configuration setup (idempotent)

echo "Setting up git configuration..."

# Set global gitignore file
git config --global core.excludesfile ~/.gitignore_global

echo "✓ Git configuration complete"
