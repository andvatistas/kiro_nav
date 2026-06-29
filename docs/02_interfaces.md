# 02 — Interfaces

## ROS 2 / Vulcanexus interface

Runtime: **Vulcanexus Humble** (ROS 2 Humble + Fast DDS). The module is a containerized Nav2 stack
with CoHAN-Nav2/HATeb as the local planner, plus an internal bridge that converts ROS4HRI
human-tracking topics into CoHAN's own message format.

### Nodes

| Node | Package | Description |
|---|---|---|
| `planner_server` | `nav2_planner` | Global path planning (NavFn). |
| `controller_server` | `nav2_controller` | Local planning via HATeb (`hateb_local_planner::HATebLocalPlannerROS`). |
| `smoother_server` | `nav2_smoother` | Velocity smoothing after the controller. |
| `behavior_server` | `nav2_behaviors` | Recovery behaviors (spin, back-up, wait). |
| `bt_navigator` | `nav2_bt_navigator` | Behavior tree navigator; exposes `/navigate_to_pose`. |
| `waypoint_follower` | `nav2_waypoint_follower` | Ordered waypoint execution. |
| `lifecycle_manager_navigation` | `nav2_lifecycle_manager` | Manages the Nav2 node lifecycle. |
| `agent_path_predict` | `agent_path_prediction` (CoHAN-Nav2) | Predicts pedestrian trajectories from `/tracked_agents`; queried by HATeb on every replan cycle. |
| `hri_to_cohan_bridge` | `kiro_nav` (`src/bridge/`) | Subscribes to ROS4HRI person topics; publishes `cohan_msgs/TrackedAgents` on `/tracked_agents`. |

### Action

| Element | Name | Type | Description |
|---|---|---|---|
| Action server | `/navigate_to_pose` | `nav2_msgs/action/NavigateToPose` | Main entry point. Send a goal pose; the stack plans, controls, and recovers until it reaches the goal or aborts. |

### Subscriptions (external inputs)

| Topic | Type | Description |
|---|---|---|
| `/map` | `nav_msgs/OccupancyGrid` | Static map served by the robot's own `map_server` / AMCL — not run inside this container. `TRANSIENT_LOCAL` QoS (Nav2 convention). |
| `/tf`, `/tf_static` | `tf2_msgs/TFMessage` | `map → odom → base_link` chain, expected from the robot's localization stack. |
| `/mobile_base_controller/odom` | `nav_msgs/Odometry` | Robot odometry; remapped from Nav2's default `odom` topic name in `config/nav_cohan.yaml`. |
| `/scan_raw` | `sensor_msgs/LaserScan` | 2D laser scan for the costmap layers. |
| `/humans/persons/tracked` | `hri_msgs/IdsList` | **Standard ROS4HRI input.** List of currently tracked person IDs, consumed by `hri_to_cohan_bridge`. Any source following the ROS4HRI convention connects without code changes. |
| `/humans/persons/<id>/position` | `hri_msgs/PointOfInterest3DStamped` | **Standard ROS4HRI input.** 3D position of each tracked person, dynamically subscribed per person ID by `hri_to_cohan_bridge`. |

**Alternative input (bypass the bridge):** publish `cohan_msgs/TrackedAgents` directly on
`/tracked_agents` if your source is not ROS4HRI-compliant (e.g. the companion simulation repo's
`hunav_to_cohan_bridge`). The CoHAN planner consumes `/tracked_agents` regardless of which upstream
wrote it.

### Internal topics (bridge output → CoHAN)

| Topic | Type | Description |
|---|---|---|
| `/tracked_agents` | `cohan_msgs/TrackedAgents` | Published by `hri_to_cohan_bridge`; consumed by `agent_path_prediction`. Not an external integration point. |

### Publication

| Topic | Type | Description |
|---|---|---|
| `/cmd_vel` | `geometry_msgs/Twist` | Socially-aware velocity command after `nav2_velocity_smoother`. |

### Internal service

| Service | Type | Description |
|---|---|---|
| `/agent_path_predict/predict_agent_poses` | `agent_path_prediction/srv/AgentPosePredict` | Called by `controller_server`'s HATeb plugin on every replan cycle to get predicted pedestrian trajectories. Internal — not an external integration point, but the nav stack cannot function if `agent_path_predict` is unavailable. |

### Key parameters (`config/nav_cohan.yaml`)

| Parameter | Value | Description |
|---|---|---|
| `FollowPath.plugin` | `hateb_local_planner::HATebLocalPlannerROS` | Selects HATeb as the local planner. |
| `tracked_agents_topic` | `/tracked_agents` | CoHAN planner's subscription to human track data (bridge output). |
| `odom_topic` | `/mobile_base_controller/odom` | Remaps Nav2's default `odom` to the robot's actual topic. |

All nodes use Nav2's standard stock QoS: `RELIABLE`/`VOLATILE` depth 10 for most topics;
`TRANSIENT_LOCAL` for `/map` and costmap topics. No custom QoS is configured in this module.

**Note on prediction mode:** the active behavior tree always requests constant-velocity pedestrian
prediction (`predict_type="const_vel"`). `config/goals.yaml` exists only to satisfy an upstream
non-empty-list assumption in `agent_path_prediction` — it does not represent real candidate
destinations, since those are generally unavailable in a live deployment.

### Launch files

| File | Purpose |
|---|---|
| `launch/cohan_nav2.launch.py` | Main Nav2 + CoHAN stack. Args: `params_file`, `map`, `use_sim_time`, `namespace`, `goals_file`. Invoked by `launch/launch.sh`. |
| `launch/hri_to_cohan_bridge.launch.py` | Starts `hri_to_cohan_bridge`. |

---

## ARISE middleware interfaces — applicability

The minimum ARISE interfaces are ROS 2/Vulcanexus, FIWARE/NGSI-LD, the DDS↔NGSI-LD enabler, and
ROS4HRI. For this module ROS 2/Vulcanexus and ROS4HRI apply; the FIWARE and DDS enabler interfaces
are **N/A by design**, justified below per the D4 guidance (§3.2.6).

### FIWARE / NGSI-LD — N/A (handled centrally in KIRO)

`kiro_nav` is a real-time navigation subsystem exchanging ROS 2 messages at planner frequency
(10–20 Hz). It does not publish state to a context broker. In the KIRO architecture, FIWARE
Orion-LD / NGSI-LD integration is centralized: the broker holds `Mission`, `Robot`, and `Worker`
entities; navigation goals reach this module indirectly (broker → mission controller FSM →
`NavigateToPose` action goal). Adding a per-module broker dependency would couple a
latency-sensitive planner to the broker and duplicate the central integration.

**Candidate NGSI-LD mapping (for reference, not implemented).** If a future deployment needed
navigation state on the broker, the natural mapping would be an update to the `Robot` entity:

```json
{
  "id": "urn:ngsi-ld:Robot:kiro",
  "type": "Robot",
  "navigationStatus":   { "type": "Property", "value": "NAVIGATING" },
  "navigationGoal":     { "type": "Property", "value": {"x": 1.5, "y": 0.5} },
  "distanceRemaining":  { "type": "Property", "value": 3.2, "unitCode": "MTR" },
  "numberOfRecoveries": { "type": "Property", "value": 0 },
  "refMission":         { "type": "Relationship", "object": "urn:ngsi-ld:Mission:delivery:001" },
  "@context": ["https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context.jsonld"]
}
```

### DDS↔NGSI-LD enabler — N/A here

The eProsima DDS Router + Fast DDS Discovery Server act as KIRO's DDS↔NGSI-LD enabler, forwarding
only the entity topics listed in the D3 integration table. The navigation action and the human-track
topics are intentionally not part of that bridge; the enabler configuration lives at KIRO system
level, not in this repository.

### ROS4HRI / ROS4RI — ✅ Standard input interface

Human tracking data arrives in standard ROS4HRI format and is converted by the internal
`hri_to_cohan_bridge` before being consumed by CoHAN-Nav2:

- **`/humans/persons/tracked`** (`hri_msgs/IdsList`) — list of active person IDs.
- **`/humans/persons/<id>/position`** (`hri_msgs/PointOfInterest3DStamped`) — one topic per tracked person, dynamically subscribed as IDs appear.

The bridge assigns a stable numeric `track_id` to each person string ID, wraps the position in a
`cohan_msgs/TrackedAgent` (one `TORSO` segment, `HUMAN` agent type), and publishes the full list
on `/tracked_agents` at 10 Hz. CoHAN consumes `/tracked_agents` without modification.

**Contributed upstream:** `hri_msgs` defined `NormalizedPointOfInterest2D` for image-plane points
of interest but had no 3D equivalent. We proposed and contributed `PointOfInterest3D` and
`PointOfInterest3DStamped` upstream, filling the
gap for stamped 3D positions with a confidence value (PR not merged yet as for 29/06/26).


