# ADR 0001: Product and technical baseline

Status: Accepted

Date: 2026-08-31

## Decision

The Last King is a top-down historical-fantasy survivor with automatic combat, army building, roguelite runs, and persistent progression.

- Godot 4.7.2 Standard and GDScript form the primary implementation.
- The Compatibility renderer and a single-threaded Web export are the baseline.
- Landscape 16:9 is the primary MVP canvas; UI must be responsive rather than pixel-positioned.
- English (US) is canonical and Vietnamese is supported at launch.
- A single gameplay core is separated from YouTube, Android, iOS, and desktop/web integrations by adapters.
- Phase 0 uses placeholders and does not depend on final art.

## Economy terminology

- `run_gold`: temporary currency earned and spent on summons during one battle.
- `account_gold`: persistent currency used for Legacy Level, Unit Mastery, and other meta progression.
- `crown_gem`: rare/premium currency.
- `royal_seal`: non-purchasable progression gate.

## Army capacity

Capacity uses integer points. The baseline starting capacity is 20 points. Content values are balance hypotheses and may change after playtesting.

## Faction roster

The roster is open-ended and is not capped at 20. The United States-associated historical entry and Persia are both retained as distinct planned factions. The Dai Viet faction led by Tran Hung Dao is the only MVP faction.

## Consequences

- Platform integration can be replaced without branching gameplay logic.
- A Web export must be tested before feature growth to expose bundle and compatibility risks early.
- Historical and cultural representation requires review before final content production.
