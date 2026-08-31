# ADR 0002: Phase 1 movement slice

Status: Accepted

Date: 2026-08-31

## Decision

Phase 1 implements only the Movement milestone from the product roadmap: Trần Hưng Đạo, an empty arena, camera follow, keyboard movement, and a virtual joystick.

- The King uses `CharacterBody2D` with immediate velocity for responsive survivor controls.
- Keyboard diagonals are normalized; virtual joystick input is analog and takes priority while active.
- The King owns its following `Camera2D`; the arena configures camera and movement limits.
- Placeholder visuals are drawn with Godot primitives so no final art dependency is introduced.
- An active movement session stores position and elapsed time in memory, without claiming Phase 10 persistence.

## Consequences

- Phase 2 can add combat without replacing movement or input code.
- Phase 3 can consume the existing BattleSession clock and King position snapshot.
- Touch and Web input are testable before mobile SDK integration.
