from prometheus_client import Counter, Gauge, Histogram

# -----------------------------------------------------------------------------
# IncidentOps metrics
# -----------------------------------------------------------------------------

incident_events_total = Counter(
    "incident_events_total",
    "Total incident events emitted",
    ["scenario", "level"]
)

incident_scenario_step = Gauge(
    "incident_scenario_step",
    "Current step of a scenario",
    ["scenario"]
)

incident_scenario_duration_seconds = Histogram(
    "incident_scenario_duration_seconds",
    "Total duration of scenario execution",
    ["scenario"]
)
