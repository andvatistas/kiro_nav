# 04 — Basic demo & how to use

The hello world ([`03`](03_installation_and_hello_world.md)) proves the install works. The **demo**
shows the module doing its actual job — a mobile robot navigating around simulated pedestrians —
without any hardware, by using the companion simulation repo. The production robot at IKH is a custom platform; a PMB2 model is used
here only because it is the readily available Gazebo model, for `examples/` purposes only.

For the full step-by-step walkthrough, see [`examples/run_demo.md`](../examples/run_demo.md).

## What the demo shows

A simulated PMB2 navigates a Gazebo Classic world shared with HuNavSim-simulated pedestrians
walking their own routes. The robot is sent a `NavigateToPose` goal and must reach it while
preserving socially aware navigation — via HATeb's
social-cost layers, instead of treating humans as static costmap obstacles.

## Expected output

- A Gazebo window opens showing the world with the PMB2 and several pedestrians.
- The nav container logs end with `Managed nodes are active` once the Nav2/HATeb stack is up.
- The goal step streams `NavigateToPose` action feedback (`distance_remaining`,
  `number_of_recoveries`) and finishes with `Goal finished with status: SUCCEEDED`.
- `/cmd_vel` shows non-zero, varying commands that visibly slow or turn when a pedestrian crosses
  close to the planned path.



## Known limitations

The simulated robot's localization is imperfect and may occasionally interfere with navigation.
Occasional recoveries (number_of_recoveries > 0) are also expected and do not indicate a failure, the
goal still completes.
