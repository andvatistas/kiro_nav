#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# run_demo.sh  –  PMB2 + HuNavSim + CoHAN-Nav2 demo, one command or step-by-step
#
# Reproduces the two-container demo documented in run_demo.md: a simulated
# PMB2 + HuNavSim pedestrians in one container, this repo's CoHAN-Nav2/HATeb
# stack in another, talking to each other over --network host DDS.
#
# Usage:
#   ./run_demo.sh                  # run every step in order (sim, nav, goal)
#   ./run_demo.sh sim               # just start the simulation container
#   ./run_demo.sh nav               # just start kiro_nav, pointed at the sim
#   ./run_demo.sh goal              # just send a navigate_to_pose goal
#   ./run_demo.sh stop              # stop both containers
#   ./run_demo.sh --no-build all    # skip docker build in both containers
#
# Run with --help for the full option list.
# ─────────────────────────────────────────────────────────────────────────────
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIRO_NAV_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SIM_REPO_DIR="${SIM_REPO_DIR:-$KIRO_NAV_DIR/../pmb2_hunav_simulation}"
GOAL_X="${GOAL_X:-1.5}"
GOAL_Y="${GOAL_Y:-0.5}"
NO_BUILD=false

usage() {
    cat <<EOF
Usage: ./run_demo.sh [OPTIONS] [STEP]

Runs the two-container PMB2 + HuNavSim + CoHAN-Nav2 demo verified during the
ARISE D4 restructuring work. With no STEP (or STEP=all), runs every step in
order -- the "one command" demo. Pass a single STEP to run just that part,
e.g. to retry a step manually or inspect the system before moving on:

  sim      Start the simulation container (pmb2_hunav_simulation)
  spawn    Manually (re)spawn the PMB2 entity -- only needed if 'sim' hits
           the known spawn_entity.py race (see kiro_nav/README.md)
  nav      Start this repo's CoHAN-Nav2 container, pointed at the simulation
  goal     Send one navigate_to_pose goal and wait for it to finish
  stop     Stop both containers
  all      Run sim, nav, goal in order (default)

Options:
  --no-build   Skip the docker build step in both containers (use once the
               images already exist, to make repeat runs fast)
  --help, -h   Show this help

Env overrides:
  SIM_REPO_DIR    Path to the pmb2_hunav_simulation checkout
                  (default: $SIM_REPO_DIR)
  GOAL_X, GOAL_Y  Nav goal coordinates in the map frame
                  (default: $GOAL_X, $GOAL_Y)
EOF
}

require_sim_repo() {
    if [ ! -d "$SIM_REPO_DIR" ]; then
        echo "[run_demo] ERROR: simulation repo not found at $SIM_REPO_DIR"
        echo "           Clone pmb2_hunav_simulation as a sibling of kiro_nav/,"
        echo "           or set SIM_REPO_DIR to point at your checkout."
        exit 1
    fi
}

step_sim() {
    require_sim_repo
    echo "[run_demo] Starting simulation container..."
    local build_flag=()
    [ "$NO_BUILD" = true ] && build_flag=(--no-build)
    (cd "$SIM_REPO_DIR" && ./run.sh --detach "${build_flag[@]}")

    if docker exec pmb2_hunav_simulation bash -c \
        "source /opt/ros/humble/setup.bash && ros2 topic list 2>/dev/null | grep -q '/mobile_base_controller/odom'" \
        >/dev/null 2>&1; then
        echo "[run_demo] PMB2 already spawned."
        return
    fi

    # Gazebo's /spawn_entity service can take 60-120s+ to become callable under
    # software rendering -- checking 'ros2 service list' first is not a reliable
    # readiness signal (the name can appear there before the service is actually
    # callable), so retry the real spawn call itself instead: spawn_entity.py
    # already waits up to 30s per attempt for the service internally.
    echo "[run_demo] Spawning PMB2 entity (retrying -- known spawn_entity.py"
    echo "           race-against-slow-world-load quirk, see kiro_nav/README.md)..."
    local attempt
    for attempt in 1 2 3 4 5 6; do
        if step_spawn; then
            echo "[run_demo] PMB2 spawned."
            return
        fi
        echo "[run_demo] Spawn attempt $attempt failed, retrying..."
    done
    echo "[run_demo] ERROR: failed to spawn PMB2 after 6 attempts."
    return 1
}

step_spawn() {
    echo "[run_demo] (Re)spawning PMB2 entity -- this is the known spawn_entity.py"
    echo "           race-against-slow-world-load quirk, see kiro_nav/README.md."
    docker exec pmb2_hunav_simulation bash -c \
        "source /opt/ros/humble/setup.bash && source /home/kiro_ws/install/setup.bash && \
         ros2 run gazebo_ros spawn_entity.py -topic robot_description -entity pmb2 \
         -robot_namespace '' -x 0.0 -y 0.0 -z 0.15 -Y 0.0 --ros-args -r __ns:=/"
}

step_nav() {
    echo "[run_demo] Starting kiro_nav container against the simulation..."
    local build_flag=()
    [ "$NO_BUILD" = true ] && build_flag=(--no-build)
    (cd "$KIRO_NAV_DIR" && ./run.sh --sim --detach "${build_flag[@]}")

    echo "[run_demo] Waiting for Nav2 lifecycle activation (up to 60s)..."
    local ready=false
    for ((i = 0; i < 60; i++)); do
        if docker logs cohan_nav2 2>&1 | grep -q "Managed nodes are active"; then
            ready=true
            break
        fi
        sleep 1
    done
    if [ "$ready" = true ]; then
        echo "[run_demo] Nav2 lifecycle is active."
    else
        echo "[run_demo] WARNING: did not see 'Managed nodes are active' within 60s, continuing anyway."
    fi
}

step_goal() {
    echo "[run_demo] Sending navigate_to_pose goal -> ($GOAL_X, $GOAL_Y)..."
    docker exec cohan_nav2 bash -c \
        "source /opt/vulcanexus/humble/setup.bash 2>/dev/null || source /opt/ros/humble/setup.bash; \
         source /home/cohan_ws/install/setup.bash && \
         ros2 action send_goal /navigate_to_pose nav2_msgs/action/NavigateToPose \
         \"{pose: {header: {frame_id: map}, pose: {position: {x: $GOAL_X, y: $GOAL_Y}, orientation: {w: 1.0}}}}\" \
         --feedback"
}

step_stop() {
    echo "[run_demo] Stopping containers (no-op if not running)..."
    docker stop cohan_nav2 pmb2_hunav_simulation 2>/dev/null || true
}

STEP="all"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-build) NO_BUILD=true; shift ;;
        --help|-h)  usage; exit 0 ;;
        sim|spawn|nav|goal|stop|all) STEP="$1"; shift ;;
        *) echo "[run_demo] Unknown argument: $1"; usage; exit 1 ;;
    esac
done

case "$STEP" in
    sim)   step_sim ;;
    spawn) step_spawn ;;
    nav)   step_nav ;;
    goal)  step_goal ;;
    stop)  step_stop ;;
    all)   step_sim; step_nav; step_goal ;;
esac
