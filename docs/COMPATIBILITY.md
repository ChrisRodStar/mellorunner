# Compatibility work

The intended first target is Melloku's source API 0.7 boundary: module initialization, source search, manga details and chapters, page discovery, and required host services.

Before implementation, write an import/export and serialization specification with source provenance for each requirement. Cover memory ownership, result framing, HTTP callbacks, settings, cancellation, and error behavior. Create deterministic fixtures from that specification. Compatibility tests must distinguish missing optional capabilities from malformed results.

An existing runner can inform a compatibility audit, but copying its implementation or translating its functions does not establish independent authorship. The ignored local checkout at `Reference/AidokuRunner` is available for reference. It is excluded from package targets; the MelloRunner implementation is separate.

No source-extension compatibility is implemented or certified yet. Decide whether legacy API 0.6 is required after the first 0.7 execution slice works.
