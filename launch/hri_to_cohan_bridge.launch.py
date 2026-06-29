"""
hri_to_cohan_bridge.launch.py
──────────────────────────────
Standalone launcher for the ROS4HRI → CoHAN bridge.
"""
from launch import LaunchDescription
from launch.actions import ExecuteProcess


def generate_launch_description():
    bridge = ExecuteProcess(
        cmd=['python3', '/src/bridge/hri_to_cohan_bridge.py'],
        name='hri_to_cohan_bridge',
        output='screen',
    )
    return LaunchDescription([bridge])
