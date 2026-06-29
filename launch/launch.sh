#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# launch.sh  –  Called INSIDE the container by run.sh
# Validates files, prints a topic check, then launches nav2.
#
# Args: $1 = params_file   $2 = map_file   $3 = use_sim_time (true/false, default false)
# ─────────────────────────────────────────────────────────────────────────────

set -e

PARAMS_FILE="${1:-/config/nav_cohan.yaml}"
MAP_FILE="${2:-/config/map.yaml}"
USE_SIM_TIME="${3:-false}"
LAUNCH_FILE="${LAUNCH_FILE:-/launch/cohan_nav2.launch.py}"

echo ""
echo "──────────────────────────────────────────"
echo " CoHAN Nav2 stack  –  ROS2 Humble"
echo " ROS_DOMAIN_ID = $ROS_DOMAIN_ID"
echo " ROS_DISCOVERY_SERVER = $ROS_DISCOVERY_SERVER"
echo " Params        : $PARAMS_FILE"
echo " Map           : $MAP_FILE"
echo " Launch        : $LAUNCH_FILE"
echo " use_sim_time  : $USE_SIM_TIME"
echo "──────────────────────────────────────────"

# ── File checks ───────────────────────────────────────────────────────────────
for f in "$PARAMS_FILE" "$MAP_FILE" "$LAUNCH_FILE"; do
    if [ ! -f "$f" ]; then
        echo "[launch.sh] ERROR: Required file not found: $f"
        echo "            Mount it via:  -v \$(pwd)/config:/config -v \$(pwd)/launch:/launch"
        exit 1
    fi
done

# ── Brief topic check (non-fatal) ─────────────────────────────────────────────
echo ""
echo "Checking expected topics from robot (5 s timeout)..."
TOPICS_OK=true
for topic in /map /tf /mobile_base_controller/odom /scan_raw /tracked_agents; do
    if timeout 5 ros2 topic info "$topic" > /dev/null 2>&1; then
        echo "  [OK]  $topic"
    else
        echo "  [--]  $topic  (not seen yet – robot may not be publishing)"
        TOPICS_OK=false
    fi
done

if [ "$TOPICS_OK" = false ]; then
    echo ""
    echo "  WARNING: Some topics missing. Navigation may not work until"
    echo "           the robot's localization stack is fully running."
fi

echo ""
echo "Launching nav stack..."
echo "──────────────────────────────────────────"

source /opt/vulcanexus/humble/setup.bash
source /home/cohan_ws/install/setup.bash


ros2 launch "$LAUNCH_FILE" \
    params_file:="$PARAMS_FILE" \
    map:="$MAP_FILE" \
    use_sim_time:="$USE_SIM_TIME"
