{
  "version": "1.0.0",
  "always_capture_commands": [
    {"id": "git-status", "argv": ["git", "status", "--short"]},
    {"id": "git-diff-stat", "argv": ["git", "diff", "--stat"]},
    {"id": "recent-commits", "argv": ["git", "log", "-5", "--oneline"]}
  ],
  "runtime_capture_commands": [
    {"id": "app-health", "enabled": false, "argv": []},
    {"id": "app-logs", "enabled": false, "argv": []},
    {"id": "app-metrics", "enabled": false, "argv": []},
    {"id": "app-traces", "enabled": false, "argv": []}
  ],
  "file_artifacts": []
}
