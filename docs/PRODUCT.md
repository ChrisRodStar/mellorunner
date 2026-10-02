# Product scope

Christopher needs a source runner for Melloku whose implementation and dependencies can be reviewed for distribution, while preserving the extension behavior the app needs.

The package will own WebAssembly execution, host import dispatch, bounded memory exchange, source-result decoding, runtime lifetime, and cancellation. Melloku will supply network policy, cookies, credentials, storage, UI, and installation transactions.

The current scaffold inspects headers. The first usable execution milestone is to load an independently authored module, invoke its `answer` export, receive 42, and release its resources. Choose and document an execution engine with suitable license terms before adding it.

Source API 0.7 is the intended first compatibility target. API 0.6 is a separate decision. Full source compatibility, distribution clearance, and performance improvements are not established by this scaffold.
