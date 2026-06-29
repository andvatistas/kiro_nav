# kiro_nav — Architecture & data flow

## Component / data-flow diagram

How `kiro_nav` fits between the robot's upstream stack and a mission controller.

```mermaid
flowchart LR
    hd["KIRO Human Detection<br/>(camera + LiDAR + UWB)"] -->|"/humans/persons/tracked<br/>hri_msgs/IdsList"| bridge
    hd -->|"/humans/persons/&lt;id&gt;/position<br/>hri_msgs/PointOfInterest3DStamped"| bridge
    bridge["hri_to_cohan_bridge<br/>(src/bridge/)"] -->|"/tracked_agents<br/>cohan_msgs/TrackedAgents"| nav

    sim["pmb2_hunav_simulation<br/>(examples/ only: HuNavSim + hunav_to_cohan_bridge)"] -->|"/tracked_agents<br/>cohan_msgs/TrackedAgents"| nav

    robot["robot upstream stack<br/>(localization · odometry · laser)"] -->|"/map · /tf · /odom · /scan_raw"| nav

    subgraph nav["kiro_nav container  ·  ROS 2 / Vulcanexus"]
        planner["planner_server (NavFn)<br/>global path"] --> hateb["controller_server<br/>(HATeb local planner)"]
        app["agent_path_predict"] -->|"/predict_agent_poses (service)"| hateb
        layers["social costmap layers<br/>(StaticAgentLayer · AgentVisibilityLayer)"] --> hateb
    end

    mc["mission controller<br/>(any ROS 2 client)"] -->|"action goal: NavigateToPose"| nav
    nav -->|"feedback: distance_remaining, recoveries"| mc
    nav -->|"result: SUCCEEDED / ABORTED"| mc
    nav -->|"/cmd_vel — socially-aware velocity"| robot
```

`kiro_nav` does not care which `/tracked_agents` source is active — the internal stack is unchanged regardless.

---

## Sequence — a `NavigateToPose` goal

```mermaid
sequenceDiagram
    participant MC as Mission controller<br/>(any ROS 2 client)
    participant KN as kiro_nav<br/>(planner + controller)
    participant APP as agent_path_predict
    participant SRC as /tracked_agents source<br/>(Human Detection or sim bridge)

    SRC-->>APP: /tracked_agents (continuous)

    MC->>KN: NavigateToPose goal
    KN->>KN: NavFn — compute global path

    loop each replan cycle
        KN->>APP: /predict_agent_poses (service call)
        APP-->>KN: predicted pedestrian trajectories
        KN->>KN: HATeb social-cost optimization
        KN-->>MC: feedback (distance_remaining, number_of_recoveries)
        KN->>robot: /cmd_vel
    end

    KN-->>MC: result SUCCEEDED
```
