# Sample report (*illustrative*)

> ⚠️ **Not a real Shakedown run.** The JSON and Markdown files in this folder are *hand-crafted examples* showing what a successful run on a 16" MacBook Pro M5 Max (64 GB) is supposed to look like. The numbers are realistic, drawn from public M5 Max review data and reasonable thermal-physics assumptions, but no actual unit produced this output.

The sample exists for two reasons:

1. **Trust signal.** Strangers landing on the repo can see what the harness produces without running it themselves.
2. **Schema reference.** The JSON conforms to [`Reports/SCHEMA.md`](../../Reports/SCHEMA.md) v1.0 and serves as a worked example for downstream consumers (the planned aggregator, alternate viewers, etc.).

Files:

- [`2026-04-30T14-30-00-mbp-16-m5-max-64.json`](2026-04-30T14-30-00-mbp-16-m5-max-64.json): the canonical schema-versioned report
- [`2026-04-30T14-30-00-mbp-16-m5-max-64.md`](2026-04-30T14-30-00-mbp-16-m5-max-64.md): the human-readable render

When real submitted reports start landing (see [Roadmap](../../README.md#roadmap)), they'll be tagged as such and this folder's purpose narrows to "format reference."

## Replacing this with a real run

Once you've run Shakedown on a known-good or known-bad unit, your report ends up in `Reports/`. To contribute it as a real example:

1. Open the JSON and double-check `submission_safe: true`, hashed serial, and that `store_location` / `purchase_date` are either null or values you're comfortable publishing.
2. Strip any free-form notes that contain identifying info.
3. Open a PR moving the file into `examples/sample-report-real/` (we'll add this folder when the first real submission arrives) along with a brief context note.
