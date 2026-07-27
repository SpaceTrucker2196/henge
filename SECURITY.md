# henge — security

## Threat model

Not yet stated — it follows from `MISSION.md`, which is unwritten. Fill this
in with the mission: what henge must protect, and from whom.

The house default across river.io software, and the assumption here until the
owner says otherwise: **data stays on the device that made it.** No accounts,
no telemetry, no analytics, no silent network.

## Outbound surface (frozen)

Every network destination, credential, and external process this repo touches.
The list is exhaustive by construction, and adding to it is a stops-and-asks
(`factory/dark-factory.md` §4) — including the first third-party package.

- **none.** `Package.swift` has no remote dependencies; the app makes no
  network calls; there are no credentials, entitlements or external processes.
  A cold clone builds offline.
