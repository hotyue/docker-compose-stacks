#!/usr/bin/env bash
set -euo pipefail

# v1.2.0 Lifecycle Definition
# This file only DECLARES lifecycle structure.
# No execution logic is included.

# -------------------------------
# Global lifecycle phases
# -------------------------------
LIFECYCLE_PHASES=("prepare" "run")

# -------------------------------
# Traccar lifecycle declarations
# -------------------------------

# Tasks executed in prepare phase for traccar
TASKS_prepare_traccar=(
  "traccar.db.init:stacks/traccar/tasks/traccar-db-init.sh"
)

