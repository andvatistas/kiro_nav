# 05 — Role in the TRL6-7 demonstrator

## Demonstrator at a glance

| Item | Value |
|---|---|
| Demonstrator | KIRO — *Demonstration of HRI-enabled solution at work* (ARISE D3) |
| Environment | IKH facilities, ARISTOS assembly production area — a live shop floor with dense layouts, narrow corridors, continuous worker presence, and variable lighting (not a lab or TEF) |
| Robot / platform | Custom IKH differential-drive mobile base carrying a UR10e arm; `kiro_nav` runs as the navigation container for the mobile base only — it has no interaction with the arm |
| End user / scenario | Shop-floor assembly workers at IKH who need on-demand tool delivery during assembly tasks |
| System TRL | 6 |
| Demonstrator video | **[KIRO full system demonstration](https://www.youtube.com/watch?v=uGGcSsZhrGk)** — includes the social navigation module in action |

## Problem the module addresses

Workers in a shared factory floor are not static obstacles — they cross the robot's path, change
direction, and occupy social-force zones that a purely geometric planner would violate. A standard
Nav2 stack treats pedestrians as static costmap inflations; `kiro_nav` replaces the local planner
with CoHAN-Nav2's HATeb, which models each tracked worker as a dynamic agent and optimises a
trajectory that avoids both physical collision and socially uncomfortable proximity. The result is a
robot that yields, routes around, and recovers gracefully in a space-constrained warehouse
environment, without requiring any change to the mission controller or the Nav2 action interface.

## Module role in the full pipeline

The KIRO mission controller (YASMIN FSM) calls `kiro_nav` for every motion task:

1. The FSM transitions to a navigation state (`NavToWarehouseState`, `NavToHomeState`, or
   `NavToTargetState`) and sends a `NavigateToPose` action goal to `/navigate_to_pose`.
2. The `bt_navigator` begins executing the CoHAN behavior tree.
3. `planner_server` (NavFn) computes a global path from `/map`.
4. On each replan cycle (20 Hz), `controller_server`'s HATeb plugin calls
   `/agent_path_predict/predict_agent_poses` to get constant-velocity pedestrian trajectories.
5. HATeb optimises a local trajectory with social costs from `StaticAgentLayer` and
   `AgentVisibilityLayer`, and publishes the result to `/cmd_vel`.
6. When the robot reaches the goal pose, the action returns `SUCCEEDED`; the FSM transitions to
   the next task (`pick_up_tool` or `handover`).

Live human tracks feed into step 4 from the separate `kiro_human_detection` container (YOLO +
LiDAR + UWB fusion), arriving in ROS4HRI format and converted by the internal `hri_to_cohan_bridge`
before reaching CoHAN.

## What was extracted as reusable vs what stays demonstrator-specific

| Demonstrator component | Reusable here (`kiro_nav`) | Stays demonstrator-specific |
|---|---|---|
| Social-aware local planning | ✅ CoHAN-Nav2/HATeb stack + `hri_to_cohan_bridge`, containerized with Docker and a documented ROS4HRI input interface | — |
| Human perception | `kiro_human_detection` (a separate stand-alone reusable module: YOLO + LiDAR + UWB fusion, its own container) | — |
| Robot localization | Documented as an external input contract (`/map`, `/tf`, odometry) — consumed, not vendored | IKH floor map + AMCL + EKF tuning |
| Mission goal selection | — | YASMIN FSM states and IKH station-specific goal poses |
| Arm + gripper control | — | MoveIt2, vacuum gripper I/O, AprilTag pick logic |

## Validation evidence

From the KIRO TRL6-7 pilot at IKH's ARISTOS assembly area:

- **Zero collisions** against walls or workers across all navigation trials.
- **Stall time consistently below 5 seconds** — the KPI threshold for acceptable recovery behavior in the shared workspace.
- Social routing confirmed in live operation: the robot visibly yielded and routed around workers, without stopping or requiring operator intervention.
- The `examples/` simulation (PMB2 + HuNavSim) reproduces the same planner behavior and has been verified in this repo's standalone Docker-packaged form.
