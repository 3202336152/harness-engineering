{
  "version": "1.0.0",
  "prepare_steps": ["feature_spec", "plan", "context_bundle"],
  "verify_steps": [
    "doc_impact",
    "spec_validation",
    "architecture_lint",
    "doc_freshness",
    "rollback_readiness"
  ],
  "verify_fail_fast": false,
  "verify_timeout_seconds": 0,
  "autofix_safe_steps": ["spec_structure"],
  "autofix_on_verify_failure": true,
  "record_context_bundles": true,
  "record_run_results": true,
  "record_metrics_ledger": true,
  "record_task_memory": true,
  "record_progress_report": true,
  "record_evidence": true,
  "evidence_on_modes": ["verify", "run"],
  "gc_on_modes": ["run"],
  "retention": {
    "keep_context_bundles": 20,
    "keep_run_records": 50,
    "keep_evidence_dirs": 20
  },
  "rollback_required_change_types": ["db", "rollout"]
}
