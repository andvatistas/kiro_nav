"""
cohan_nav2.launch.py
────────────────────
Launches the CoHAN Nav2 navigation stack ONLY.
Assumes the robot and other nodes already publishes:
  /map  /tf (map→odom→base_link)  /mobile_base_controller/odom  /scan_raw
  /tracked_agents (cohan_msgs/TrackedAgents) -- pedestrian/human tracks, from
  whatever upstream source (simulated or real); see docs/02_interfaces.md.

Volume-mounted into the container at /launch/.
Run via:  ros2 launch /launch/cohan_nav2.launch.py
          params_file:=/config/nav_cohan.yaml
"""

import os
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, GroupAction, LogInfo
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node, PushRosNamespace
from launch_ros.substitutions import FindPackageShare
from nav2_common.launch import RewrittenYaml


def generate_launch_description():

    # ── Launch arguments ──────────────────────────────────────────────────────
    params_file_arg = DeclareLaunchArgument(
        'params_file',
        default_value='/config/nav_cohan.yaml',
        description='Full path to the Nav2 + CoHAN parameters yaml'
    )
    map_arg = DeclareLaunchArgument(
        'map',
        default_value='/config/map.yaml',
        description='Full path to the map yaml'
    )
    use_sim_time_arg = DeclareLaunchArgument(
        'use_sim_time',
        default_value='false',
        description='Use simulation clock (set true for Gazebo)'
    )
    namespace_arg = DeclareLaunchArgument(
        'namespace',
        default_value='',
        description='Robot namespace'
    )
    goals_file_arg = DeclareLaunchArgument(
        'goals_file',
        default_value='/config/goals.yaml',
        description='Full path to the candidate-destinations yaml for agent_path_predict'
    )

    params_file    = LaunchConfiguration('params_file')
    use_sim_time   = LaunchConfiguration('use_sim_time')
    goals_file     = LaunchConfiguration('goals_file')

    param_substitutions = {'use_sim_time': use_sim_time}
    configured_params = RewrittenYaml(
        source_file=params_file,
        root_key=None, #namespace,
        param_rewrites=param_substitutions,
        convert_types=True
    )

    planner_server = Node(
        package='nav2_planner',
        executable='planner_server',
        name='planner_server',
        output='screen',
        parameters=[configured_params]
    )

    controller_server = Node(
        package='nav2_controller',
        executable='controller_server',
        name='controller_server',
        output='screen',
        parameters=[configured_params],
        remappings=[
            ('cmd_vel', '/cmd_vel'),
            ('odom',    '/mobile_base_controller/odom'),
        ]
    )

    smoother_server = Node(
        package='nav2_smoother',
        executable='smoother_server',
        name='smoother_server',
        output='screen',
        parameters=[configured_params]
    )

    behavior_server = Node(
        package='nav2_behaviors',
        executable='behavior_server',
        name='behavior_server',
        output='screen',
        parameters=[configured_params],
        remappings=[('cmd_vel', '/cmd_vel')]
    )

    bt_navigator = Node(
        package='nav2_bt_navigator',
        executable='bt_navigator',
        name='bt_navigator',
        output='screen',
        parameters=[configured_params],
        remappings=[('odom', '/mobile_base_controller/odom')]
    )

    waypoint_follower = Node(
        package='nav2_waypoint_follower',
        executable='waypoint_follower',
        name='waypoint_follower',
        output='screen',
        parameters=[configured_params]
    )

    velocity_smoother = Node(
        package='nav2_velocity_smoother',
        executable='velocity_smoother',
        name='velocity_smoother',
        output='screen',
        parameters=[configured_params],
        remappings=[
            ('cmd_vel',        '/cmd_vel_nav'),
            ('cmd_vel_smoothed', '/cmd_vel'),
        ]
    )

    lifecycle_manager = Node(
        package='nav2_lifecycle_manager',
        executable='lifecycle_manager',
        name='lifecycle_manager_navigation',
        output='screen',
        parameters=[{
            'use_sim_time':  use_sim_time,
            'autostart':     True,
            'node_names': [
                # 'map_server',
                'planner_server',
                'controller_server',
                'smoother_server',
                'behavior_server',
                'bt_navigator',
                'waypoint_follower',
                'velocity_smoother',
                # CoHAN-specific nodes managed separately below
            ]
        }]
    )

    agent_path_predict = Node(
        package='agent_path_prediction',
        executable='agent_path_predict',
        name='agent_path_predict',
        output='screen',
        parameters=[{
            'use_sim_time': use_sim_time,
            'goals_file': goals_file,
        }]
)

    return LaunchDescription([
        # Args
        params_file_arg,
        map_arg,
        use_sim_time_arg,
        namespace_arg,
        goals_file_arg,

        LogInfo(msg="Starting CoHAN Nav2 stack (nav only – localization on robot)"),
        # Nav stack
        # map_server,
        planner_server,
        controller_server,
        smoother_server,
        behavior_server,
        bt_navigator,
        waypoint_follower,
        velocity_smoother,
        lifecycle_manager,

        # CoHAN extras
        agent_path_predict,
    ])
