#!/bin/bash
##- Git configuration setup (idempotent)

echo "Setting up git configuration..."

git config --global user.name "Aslan French"
git config --global user.email "howdy@aslanfrench.work"
git config --global core.excludesfile ~/.gitignore_global

echo "✓ Git configuration complete"
