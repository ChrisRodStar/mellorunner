# Provenance

The scaffold was written for this project. Its header rules and fixture encoding come from the [WebAssembly binary module specification](https://webassembly.github.io/spec/core/binary/modules.html). The fixture generator records the byte encoding and equivalent module expression.

AidokuRunner is cloned locally at `Reference/AidokuRunner`, from `https://github.com/Aidoku/AidokuRunner.git`, initially at revision `cc4d06ff399e7169b9c647bccede7cb29bc805c6`. The entire `Reference` directory is ignored by Git; it is not a submodule or a package dependency. Upstream licensing terms remain in the checkout.

No AidokuRunner implementation or source-extension fixture has been copied into the MelloRunner library or tests. Earlier conversations and development work inspected AidokuRunner; this project therefore makes no clean-room claim.

For future code and specifications, record the source, revision, applicable terms, and whether material was copied or implemented independently. Review any runtime dependency separately. A rewrite or different API choice alone does not establish distribution rights. No distribution clearance or project license decision is claimed here.
