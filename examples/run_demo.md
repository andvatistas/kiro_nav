# Basic demo — simulated PMB2 navigating around simulated pedestrians

Reproduces the two-container demo verified during the ARISE D4 restructuring work: a simulated PMB2 + HuNavSim pedestrians in one container, this repo's CoHAN-Nav2/HATeb stack in another, talking to each other over `--network host` DDS. This is an `examples/`-only stand-in — the production robot at IKH is a different, custom platform; PMB2 is used here only because it's a readily available Gazebo model. See `kiro_nav/README.md`'s Architecture section for the real-vs-simulation split. In order to test the module in a real robot, you need the robot running localization and odometry, the kiro_human_detection module running (publishing the human detections), and to just run the kiro_nav/run.sh script. This markdown offers a step-by-step simulation guide.

## Prerequisites

- Docker, with X11 forwarding available (`xhost +local:docker` — both `run.sh` scripts do this for you).
- The companion simulation repo cloned as a sibling directory:
  ```
  pmb2_hunav_simulation/   <- sibling repo, see its own README
  kiro_nav/                <- this repo
  ```

- Clone the companion repo using the command:
  ```
  git clone https://github.com/andvatistas/pmb2_hunav_simulation.git
  ```

## Quick path: run_demo.sh

`./run_demo.sh` runs the whole demo below in one command (start the simulation, start `kiro_nav`, send a nav goal). It also works step-by-step — useful for retrying a single step or inspecting the system in between:

```bash
./run_demo.sh sim     # start the simulation container
./run_demo.sh nav     # start kiro_nav, pointed at the simulation
./run_demo.sh goal    # send a navigate_to_pose goal
./run_demo.sh stop    # stop both containers
```

Run `./run_demo.sh --help` for all options (including `--no-build` for fast repeat runs, and `SIM_REPO_DIR`/`GOAL_X`/`GOAL_Y` env overrides). This script is recommended. The rest of this document is the fully-manual, raw-command walkthrough that `run_demo.sh` automates — use it if you want to see or control every step directly.


## 1. Start the simulation container

From `pmb2_hunav_simulation/`:

```bash
./run.sh
```

Wait for the Gazebo window to appear and load the warehouse world — this can take 30–60s+ under software rendering, that's expected. Once loaded, confirm the robot actually spawned:

```bash
docker exec pmb2_hunav_simulation bash -c \
  "source /opt/ros/humble/setup.bash && ros2 service list | grep spawn_entity"
```

**Known quirk:** `spawn_entity.py` has no built-in retry and can occasionally race against the slow world-load, dying with `Service /spawn_entity unavailable`. If that happens, just re-run it manually once the service above is listed:

```bash
docker exec pmb2_hunav_simulation bash -c \
  "source /opt/ros/humble/setup.bash && source /home/kiro_ws/install/setup.bash && \
   ros2 run gazebo_ros spawn_entity.py -topic robot_description -entity pmb2 \
   -robot_namespace '' -x 0.0 -y 0.0 -z 0.15 -Y 0.0 --ros-args -r __ns:=/"
```

You should then see `/scan_raw`, `/tf`, `/mobile_base_controller/odom`, and `/human_states` all publishing real data. The container's default launch also starts the `hunav_to_cohan_bridge` node, so `/tracked_agents` (`cohan_msgs/TrackedAgents`) — the actual interface `kiro_nav` consumes — should be publishing too; confirm with `ros2 topic hz /tracked_agents`.

## 2. Start this container, pointed at the simulation

From `kiro_nav/`:

```bash
./run.sh --sim
```

`--sim` does two things needed for this two-container-on-one-host setup: sets `use_sim_time:=true` (so the nav stack's clock tracks Gazebo's simulated time instead of the wall clock — without it, TF lookups eventually fail with extrapolation errors), and switches DDS transport to `FASTDDS_BUILTIN_TRANSPORTS=UDPv4` without `--ipc host` (without this, FastDDS can silently fail to deliver topic data between the two containers even though discovery looks fine). Wait for `Managed nodes are active` in the logs.

## 3. Send a navigation goal

```bash
docker exec -it cohan_nav2 bash -c \
  "source /opt/vulcanexus/humble/setup.bash && source /home/cohan_ws/install/setup.bash && \
   ros2 action send_goal /navigate_to_pose nav2_msgs/action/NavigateToPose \
   \"{pose: {header: {frame_id: map}, pose: {position: {x: 1.5, y: 0.5}, orientation: {w: 1.0}}}}\" \
   --feedback"
```

(Pick an `x`/`y` inside the loaded map, ideally crossing a pedestrian's path — check current positions with `ros2 topic echo /human_states --once`.)

**Expected output:** the action reports incrementing `navigation_time` / decreasing `distance_remaining`, the robot visibly moves toward the goal in the Gazebo window, and `/cmd_vel` shows non-zero, varying commands — including slowing/turning if a pedestrian crosses close to the planned path. The action should finish with `Goal finished with status: SUCCEEDED`.

