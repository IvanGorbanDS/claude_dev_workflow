# Cost Ledger — test-task

# 6-column row (no fallback_fires column)
aaaaaaaa-0000-0000-0000-000000000001 | 2026-04-15 | plan | claude-opus-4-7 | task | "early plan session"
# 7-column row with fallback_fires=2
bbbbbbbb-0000-0000-0000-000000000002 | 2026-05-01 | implement | claude-sonnet-4-6 | task | "implement session" | 2
# 7-column row with fallback_fires=0, date after cutoff
cccccccc-0000-0000-0000-000000000003 | 2026-05-02 | critic | claude-opus-4-7 | task | "critic session" | 0
# Row with template UUID — must be skipped
$(uuidgen) | 2026-05-02 | plan | claude-sonnet-4-6 | task | "template artifact" | 0
# Non-task category row — must be skipped
dddddddd-0000-0000-0000-000000000004 | 2026-05-03 | ad-hoc | claude-sonnet-4-6 | meta | "not a task row" | 0
# Row whose JSONL exists (used by test_report_structure to assert totalCost > 0)
eeeeeeee-0000-0000-0000-000000000005 | 2026-05-03 | implement | claude-sonnet-4-6 | task | "jsonl-matched session" | 1
