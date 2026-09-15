# MoonJMES Playground

The playground is a static browser client for the reusable library. Its
MoonBit model owns JSON parsing, expression compilation, evaluation, plans,
traces, and diagnostics. The JavaScript module only renders that structured
response and manages browser interactions.

Build and assemble a local static bundle from the repository root:

```console
moon build playground/app --target js --release
moon run tools/assemble_playground.mbtx _build/js/release/build/playground/app/app.js playground/dist
```

Serve `playground/dist` with any static HTTP server. Generated JavaScript and
assembled output are intentionally excluded from version control; CI rebuilds
them from MoonBit source for deployment.
