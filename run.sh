#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# run.sh  –  Build (optional) and launch CoHAN Nav2 stack
#
# Usage:
#   ./run.sh                          # uses defaults
#   ./run.sh --no-build               # skip docker build (image already exists)
#   ./run.sh --shell                  # drop into a bash shell inside the container
# ─────────────────────────────────────────────────────────────────────────────

set -e

# ── Defaults ──────────────────────────────────────────────────────────────────
IMAGE_NAME="cohan_nav2:latest"
CONFIG_DIR="$(pwd)/config"
LAUNCH_DIR="$(pwd)/launch"
SRC_DIR="$(pwd)/src"
PARAMS_FILE="/config/nav_cohan.yaml"
MAP_FILE="/config/map.yaml"
# ROS_DOMAIN_ID=25
ROS_DISCOVERY_SERVER="10.0.17.100:11811"
ROS_SUPER_CLIENT="TRUE"
BUILD=true
SHELL_MODE=false
USE_SIM_TIME=false
DETACH=false


# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --params)    PARAMS_FILE="$2";  shift 2 ;;
        --domain)    ROS_DOMAIN_ID="$2"; shift 2 ;;
        --config)    CONFIG_DIR="$2";   shift 2 ;;
        --launch-dir) LAUNCH_DIR="$2";  shift 2 ;;
        --no-build)  BUILD=false;       shift ;;
        --shell)     SHELL_MODE=true;   shift ;;
        --sim)       USE_SIM_TIME=true; shift ;;
        --detach|-d) DETACH=true;       shift ;;
        --help|-h)
            echo "Usage: ./run.sh [OPTIONS]"
            echo "  --params FILE    Nav2 params yaml  (default: /config/nav_cohan.yaml)"
            echo "  --domain ID      ROS_DOMAIN_ID      (default:  not set)"
            echo "  --config DIR     Host config dir    (default: ./config/)"
            echo "  --launch-dir DIR Host launch dir     (default: ./launch/)"
            echo "  --no-build       Skip docker build"
            echo "  --shell          Open bash shell instead of launching nav stack"
            echo "  --sim            Use simulation clock (use_sim_time:=true) -- pass when"
            echo "                   running against a simulated robot (e.g. pmb2_hunav_simulation)"
            echo "                   instead of a real robot's wall-clock-synced stack"
            echo "  --detach, -d     Run detached (-d) instead of interactively (-it) --"
            echo "                   used by examples/run_demo.sh to script both containers"
            exit 0 ;;
        *) echo "[run.sh] Unknown argument: $1"; exit 1 ;;
    esac
done

# ── Build ─────────────────────────────────────────────────────────────────────
if [ "$BUILD" = true ]; then
    echo ""
    echo "═══════════════════════════════════════════"
    echo "  Building image: $IMAGE_NAME"
    echo "═══════════════════════════════════════════"
    docker build -t "$IMAGE_NAME" -f docker/Dockerfile .
fi

# ── Validate config/launch dirs ────────────────────────────────────────────────
if [ ! -d "$CONFIG_DIR" ]; then
    echo "[run.sh] ERROR: Config directory not found: $CONFIG_DIR"
    echo "         Create ./config/ and place your yaml files there."
    exit 1
fi
if [ ! -d "$LAUNCH_DIR" ]; then
    echo "[run.sh] ERROR: Launch directory not found: $LAUNCH_DIR"
    echo "         Create ./launch/ and place launch.sh / cohan_nav2.launch.py there."
    exit 1
fi

# ── Decide what to run inside the container ───────────────────────────────────
if [ "$SHELL_MODE" = true ]; then
    CONTAINER_CMD="bash"
else
    CONTAINER_CMD="bash /launch/launch.sh $PARAMS_FILE $MAP_FILE $USE_SIM_TIME"
fi

if [ "$DETACH" = true ]; then
    TTY_FLAG="-d"
else
    TTY_FLAG="-it"
fi

echo ""
echo "═══════════════════════════════════════════"
echo "  Starting CoHAN Nav2 container"
echo "  Config dir : $CONFIG_DIR"
echo "  Launch dir : $LAUNCH_DIR"
echo "  Params     : $PARAMS_FILE"
echo "  Map        : $MAP_FILE"
echo "  use_sim_time: $USE_SIM_TIME"
echo "  ROS domain : $ROS_DOMAIN_ID"
echo "  ROS Discovery Server : $ROS_DISCOVERY_SERVER"
echo "═══════════════════════════════════════════"
echo ""

# ── DDS flags ─────────────────────────────────────────────────────────────────
# Simulation (a sibling container on the same host, e.g. pmb2_hunav_simulation)
# needs NO --ipc host and FASTDDS_BUILTIN_TRANSPORTS=UDPv4: FastDDS otherwise
# prefers a shared-memory transport that silently fails to cross mismatched IPC
# namespaces (discovery looks fine, but no topic data actually flows). A real
# robot is reached over the network, not local IPC, so --ipc host is harmless
# there and ROS_DISCOVERY_SERVER/ROS_SUPER_CLIENT are what's actually needed.
DDS_FLAGS=()
if [ "$USE_SIM_TIME" = true ]; then
    DDS_FLAGS+=(-e FASTDDS_BUILTIN_TRANSPORTS=UDPv4)
else
    DDS_FLAGS+=(--ipc host)
    DDS_FLAGS+=(-e ROS_DISCOVERY_SERVER="$ROS_DISCOVERY_SERVER")
    DDS_FLAGS+=(-e ROS_SUPER_CLIENT="$ROS_SUPER_CLIENT")
fi

# ── docker run ────────────────────────────────────────────────────────────────
docker run \
    --rm \
    "$TTY_FLAG" \
    --name cohan_nav2 \
    --network host \
    --pid host \
    -v "$CONFIG_DIR":/config \
    -v "$LAUNCH_DIR":/launch \
    -v "$SRC_DIR":/src \
    -e RMW_IMPLEMENTATION=rmw_fastrtps_cpp \
    "${DDS_FLAGS[@]}" \
    "$IMAGE_NAME" \
    $CONTAINER_CMD

