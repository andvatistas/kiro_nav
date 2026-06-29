# 03 — Installation & hello world

The supported and recommended runtime is **Docker** (Vulcanexus Humble image). The **hello world**
here is minimal — it only confirms the install works and CoHAN-Nav2 built correctly. To see the
robot actually navigating around pedestrians, run the **demo** in
[`04_basic_demo_how_to_use.md`](04_basic_demo_how_to_use.md).

## Dependencies

| Category | Hello world | Full demo | Where |
|---|---|---|---|
| Operating system | Linux with Docker Engine | Same | `run.sh`, `docker/Dockerfile` |
| ROS 2 / Vulcanexus | None on the host — Humble + Vulcanexus is baked into the image | Same | `docker/Dockerfile`: `FROM eprosima/vulcanexus:humble-desktop` |
| CoHAN-Nav2 deps | None on the host — CoHAN-Nav2, HATeb, `costmap_converter`, `g2o` are cloned and built inside the image | Same | `docker/Dockerfile` |
| Docker | Required | Required | `run.sh` |
| FIWARE / Context Broker | Not required | Not required | `docs/02_interfaces.md` |
| Hardware | **None** | **None** (companion simulation repo stands in) | `docs/01_arise_context.md` target platforms |
| Companion simulation repo | Not required | Required — [`pmb2_hunav_simulation`](../../pmb2_hunav_simulation), cloned as a sibling directory | `examples/run_demo.md` |

## Install (Docker)

```bash
# from repository root
chmod +x run.sh
./run.sh --shell
```

`--shell` builds the image (several minutes) and drops you into a bash shell inside the container. No robot or simulation
needed for this step.

## Hello world — confirm CoHAN-Nav2 installed correctly

Inside the container shell:

```bash
ros2 pkg list | grep -iE 'cohan|agent_path_prediction|costmap_converter|hateb_local_planner'
```

### Expected output

```
agent_path_prediction
cohan_layers
cohan_msgs
cohan_sim
cohan_sim_navigation
costmap_converter
costmap_converter_msgs
hateb_local_planner
```

Seeing all eight packages listed confirms that CoHAN-Nav2, HATeb, and their dependencies all
installed and built correctly. Stop the shell with `exit`.


## Native (no Docker)

Native installation is possible but requires building CoHAN-Nav2, HATeb, `costmap_converter`, and
`g2o` from source against a Vulcanexus Humble install — the same steps `docker/Dockerfile`
automates. Docker is strongly recommended. If you do need a native setup, follow the build steps in
`docker/Dockerfile` as a reference script.

## Next: the demo

To run the full demo — a simulated PMB2 navigating around HuNavSim pedestrians — continue to
[`04_basic_demo_how_to_use.md`](04_basic_demo_how_to_use.md).

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Build takes very long or fails cloning CoHAN | Network access required during `docker build`; retry on a stable connection. CoHAN is cloned from GitHub. |
| `ros2 pkg list` is empty inside the shell | Source the workspace: `source /home/cohan_ws/install/setup.bash` |
| `hateb_local_planner` not listed | Build failed silently — check `docker build` output for CMake errors. `g2o` and `costmap_converter` must build before HATeb. |
| Nodes don't see each other in the demo | DDS discovery — use `--net=host`; align `ROS_DOMAIN_ID` across containers. For two containers on the same host with `--sim`, the `run.sh` switches to `FASTDDS_BUILTIN_TRANSPORTS=UDPv4` automatically. |
| TF extrapolation errors in the demo | Clocks are out of sync — ensure `./run.sh --sim` (not just `./run.sh`) is used when running against the simulation container. |
| Nav2 lifecycle nodes don't activate | Usually a missing upstream topic (`/map`, `/tf`, `/scan_raw`, odometry). Check `ros2 topic hz <topic>` for each expected input. |
