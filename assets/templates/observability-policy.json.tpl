{
  "version": "1.0.0",
  "always_capture_commands": [
    {"id": "git-status", "command": "git status --short"},
    {"id": "git-diff-stat", "command": "git diff --stat"},
    {"id": "recent-commits", "command": "git log -5 --oneline"}
  ],
  "runtime_capture_commands": [
    {"id": "app-health", "enabled": false, "command": ""},
    {"id": "app-logs", "enabled": false, "command": ""},
    {"id": "app-metrics", "enabled": false, "command": ""},
    {"id": "app-traces", "enabled": false, "command": ""}
  ],
  "file_artifacts": []
}
