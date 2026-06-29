# 01 — ARISE Context

## What this module is

`kiro_nav` is the **Social-Aware Navigation** reusable module produced by the **KIRO** experiment (*Key Intelligent & Interactive Robotic Operator*), funded under the ARISE 1st Open Call (Horizon Europe, GA 101135784, lead **IKNOWHOW SA**). It packages, as open and independently runnable software, the social-aware navigation stack of the KIRO TRL6-7 demonstrator: a ROS 2 / Vulcanexus containerized Nav2 stack using the CoHAN-Nav2 / HATeb local planner, enabling a mobile robot to navigate safely around workers in shared spaces.


## KIRO in one paragraph

KIRO is an HRI-enabled mobile manipulator (UR10e arm on a mobile base) that delivers tools to shop-floor operators on demand. A worker requests a tool by voice/app; an LLM agent and the FIWARE Orion-LD context broker resolve the request into a mission; a ROS 2 mission controller (a YASMIN state machine) then **drives socially-aware navigation**, tool recognition + picking, and a socially / ergonomically aware handover. KIRO reached **TRL 6** in a pilot at IKH's ARISTOS assembly area.

## Where this module sits in the demonstrator

`kiro_nav` provides the navigation capability, used whenever the robot must move to any pose in the shared workspace — navigating to a tool station, approaching a worker for handover, or any other waypoint:

```
user voice/app request
        │  (FIWARE Orion-LD)
        ▼
kiro_mission_controller (FSM - Robot)
        │
   NavigateToPose  ──► nav goal client → /navigate_to_pose  (THIS MODULE)
   (to station,   │                          goal: target pose
    to worker,    │                          ▼
    or any pose)  │                  kiro_nav  (CoHAN-Nav2 / HATeb)
        │         │                     ├── /humans/persons/tracked (/tracked_agents)  ← KIRO Human Detection
        │         │                     ├── /map · /tf · /scan_raw  ← robot stack
        │         │                     └── /cmd_vel → robot base
        ▼
   pick_up_tool / handover tasks
```

`kiro_nav` does not know or care about the mission context — it receives a `NavigateToPose` goal and returns `SUCCEEDED` or `ABORTED`. The social awareness (yielding to, routing around workers) happens inside the HATeb optimizer, driven by live `/tracked_agents` data, invisibly to the caller.

## What is open here

The complete navigation capability is open: the ROS 2 / Nav2 configuration, CoHAN-Nav2 integration, launch files, Dockerfile, and the `run.sh` / `run.sh --sim` entry points. The simulation stand-in (companion [`pmb2_hunav_simulation`](../../pmb2_hunav_simulation) repo) is also fully open. What remains demonstrator-specific — the mission controller, grasping logic and the robot's sensor-fusion pipeline for localization .

## ARISE middleware alignment (summary)

| Concern | This module |
|---|---|
| **ROS 2 / Vulcanexus** | ✅ Core interface. Vulcanexus Humble; standard Nav2 stack + CoHAN-Nav2/HATeb, exposed as a `nav2_msgs/NavigateToPose` action server over Fast DDS. |
| **FIWARE / NGSI-LD** | N/A for this module — navigation is a real-time ROS 2 subsystem. FIWARE/Orion-LD integration is handled centrally in KIRO (Mission/Robot/Worker entities) at mission level, not by this planner. See [`02_interfaces.md`](02_interfaces.md). |
| **DDS↔NGSI-LD enabler** | N/A here — the eProsima enabler bridges entity topics at KIRO system level. This module's external interfaces (`/humans/persons/tracked` in, `/cmd_vel` out) are plain DDS between sibling containers. |
| **ROS4HRI / ROS4RI** | ✅ Standard input interface. Human tracks arrive in ROS4HRI format (`hri_msgs/IdsList` on `/humans/persons/tracked` + `hri_msgs/PointOfInterest3DStamped` per person), converted internally by `hri_to_cohan_bridge` before being consumed by CoHAN. The `PointOfInterest3DStamped` message type was proposed and contributed upstream to `hri_msgs`. See [`02_interfaces.md`](02_interfaces.md#ros4hri--ros4ri-alignment). |

## Connection with ARISE

`kiro_nav` provides a containerized, ready-to-deploy ROS 2 Humble (Vulcanexus) stack for human-aware autonomous navigation. It packages the CoHAN planner — including the HATEB local planner and social costmap layers (`StaticAgentLayer`, `AgentVisibilityLayer`) — behind the standard Nav2 `/navigate_to_pose` action interface, requiring no knowledge of the internal planning architecture from the caller. The module accepts human tracking data on the `/tracked_agents` topic (`cohan_msgs/msg/TrackedAgents`) and can therefore be paired with any upstream perception pipeline that publishes to this interface. This decoupled design is what makes the module reusable across different robotic platforms and industrial scenarios with minimal integration effort — exactly the "extract a meaningful reusable asset" goal of the ARISE D4 Reusable Module deliverable.

For the technical specifics of how this connects to ARISE's required interfaces — ROS 2/Vulcanexus, FIWARE/NGSI-LD, DDS integration, and ROS4HRI/ROS4RI alignment (including a proposed ROS4HRI extension) — see `docs/02_interfaces.md`.

## Target platforms

| Target platform category | Tested on | Expected compatibility | Not supported or unknown |
|---|---|---|---|
| Mobile robot | IKH's custom differential-drive mobile robot — at IKH's premises (real robot, warehouse environment) as part of the KIRO TRL6-7 demonstrator. Also verified in simulation against a PMB2 model via the companion [`pmb2_hunav_simulation`](../../pmb2_hunav_simulation) repo, but only for `examples/` — PMB2 is not the production platform. | Any differential-drive mobile robot that publishes `/tf`, odometry, and a 2D laser scan, and can run a Nav2 `controller_server` | Holonomic or non-differential-drive platforms not verified. |
| Sensors | Real: camera + LiDAR + UWB fusion, via the separate KIRO Human Detection module (https://github.com/nikolaslps/human_detection_fusion). Simulated: Tracking workers/humans from the Gazebo rendering for stand-alone testing purposes | Any sensor pipeline that ultimately publishes `hri_msgs/IdsList` on `/humans/persons/tracked` and `hri_msgs/PointOfInterest3DStamped` on `/humans/persons/<id>/position` | Depth-camera-only sources not verified/tested. |




## Off-the-shelf capabilities

Available immediately from a fresh checkout, Docker build only, no code changes:

- Human-aware local planning/obstacle avoidance for a differential-drive robot, given the inputs listed in `docs/02_interfaces.md`, tested on IKH's custom robot platform; the companion simulation repo's PMB2 is an `examples/`-only stand-in.
- A working Nav2 stack (planner/controller/behavior/bt_navigator/waypoint follower/velocity smoother) pre-wired to CoHAN-Nav2's HATeb social-aware local planner in place of Nav2's default controllers.
- A standard `navigate_to_pose` action interface, usable from any ROS 2 client (RViz2, a custom behavior tree, a script) with no extra integration code.
- Two operating modes via one launch flag (`run.sh` vs. `run.sh --sim`): real-robot wall-clock operation (paired with the KIRO Human Detection module in production), or simulated-clock operation against the companion simulation repo for `examples/`.

Maturity: the underlying CoHAN-Nav2 integration has been run and tested at IKH's premises as part of the full KIRO stack; this repo's standalone Docker-packaged form has been verified end-to-end against the companion simulation repo and the real robot hardware at IKH's premises (see `docs/03`, `docs/04`).

## ROS4HRI / ROS4RI applicability

Applied — see [`02_interfaces.md`](02_interfaces.md#ros4hri--ros4ri-alignment) for the full explanation. Human tracking data is consumed in standard ROS4HRI format (`hri_msgs/IdsList` + `hri_msgs/PointOfInterest3DStamped`) and converted internally via `src/bridge/hri_to_cohan_bridge.py` into CoHAN's own `cohan_msgs/TrackedAgents` representation. The `PointOfInterest3DStamped` message type was proposed and contributed upstream to `hri_msgs` as part of this work.
