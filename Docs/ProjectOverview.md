# RobloxTemplateProject Overview

## Goal

`RobloxTemplateProject` is a public starter repository for Roblox development in Luau.
It provides a clean baseline that anyone can clone and extend.

## Included baseline

- Rojo mapping via `default.project.json`
- Source split into `src/client`, `src/server`, and `src/shared`
- Toolchain pinning with Rokit
- Wally package management setup
- Selene linting setup

## Development model

- Keep gameplay authority on the server.
- Keep shared modules deterministic and reusable.
- Keep client code focused on input and presentation.
- Build in small, testable steps.

## Intended use

Use this repository as a starting point for new Roblox games, prototypes, or systems.
Add only the dependencies and services your game actually needs.
