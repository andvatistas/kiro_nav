# media/

Visual evidence for the ARISE D4 deliverable:

- `architecture_diagrams.md` — System diagrams: component/data-flow diagram showing the kiro_nav container, its internal CoHAN-Nav2 nodes, and the two upstream /tracked_agents sources (production vs. simulation); and a sequence diagram for a single NavigateToPose goal.
- `screenshots/` — RViz screenshots from the real IKH deployment, taken from the ARISE D3 report:
  - `global_costmap_warehouse.png` — global costmap with the robot's footprint and inflated obstacle costs.
  - `local_costmap_social_zone.png` — local costmap showing the social-cost zone raised around a tracked worker, plus the robot's local plan routing around it.
  - `robot_at_ikh.png` — the physical robot (custom mobile base + UR10e arm + gripper) on the IKH shop floor.
- `video_link.md` — link to the demonstrator video.
