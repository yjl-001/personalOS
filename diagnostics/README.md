# Diagnostics Map

This directory contains validation and cleanup utilities for live FlowUS environments.

- `cleanup_flowus_records.rb`: remove duplicate or test records
- `lint_flowus_wiki.rb`: audit the live knowledge base for structural issues
- `real_ingest_flowus.rb`: run a real end-to-end ingest validation flow

These are operational tools, not first-line entrypoints.
