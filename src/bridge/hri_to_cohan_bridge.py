#!/usr/bin/env python3
"""Bridges ROS4HRI person topics into CoHAN's cohan_msgs/TrackedAgents.

Subscribes to:
  /humans/persons/tracked           (hri_msgs/IdsList)
  /humans/persons/<id>/position     (hri_msgs/PointOfInterest3DStamped)

Publishes:
  /tracked_agents                   (cohan_msgs/TrackedAgents)
"""
import rclpy
from rclpy.node import Node

from geometry_msgs.msg import Pose
from hri_msgs.msg import IdsList, PointOfInterest3DStamped
from cohan_msgs.msg import AgentType, TrackedAgent, TrackedAgents, TrackedSegment, TrackedSegmentType


class HriToCohanBridge(Node):
    def __init__(self):
        super().__init__('hri_to_cohan_bridge')
        self.declare_parameter('tracked_topic', '/humans/persons/tracked')
        self.declare_parameter('output_topic', '/tracked_agents')
        self.declare_parameter('publish_rate', 10.0)
        self.declare_parameter('default_frame', 'map')

        tracked_topic  = self.get_parameter('tracked_topic').value
        output_topic   = self.get_parameter('output_topic').value
        publish_rate   = self.get_parameter('publish_rate').value
        self._default_frame = self.get_parameter('default_frame').value

        self._pub = self.create_publisher(TrackedAgents, output_topic, 10)
        self.create_subscription(IdsList, tracked_topic, self._tracked_cb, 10)

        self._active_ids: set = set()
        self._subs: dict = {}
        self._latest: dict = {}   # person_id -> PointOfInterest3DStamped
        self._id_map: dict = {}   # person_id (str) -> track_id (uint32)
        self._next_track_id: int = 0

        self.create_timer(1.0 / publish_rate, self._publish_cb)

        self.get_logger().info(
            f'hri_to_cohan_bridge: {tracked_topic} + per-person /position '
            f'-> {output_topic} @ {publish_rate:.0f}Hz'
        )

    def _assign_track_id(self, person_id: str) -> int:
        if person_id not in self._id_map:
            self._id_map[person_id] = self._next_track_id
            self._next_track_id += 1
        return self._id_map[person_id]

    def _tracked_cb(self, msg: IdsList):
        new_ids = set(msg.ids)
        added   = new_ids - self._active_ids
        removed = self._active_ids - new_ids

        for pid in added:
            self._assign_track_id(pid)
            topic = f'/humans/persons/{pid}/position'
            self._subs[pid] = self.create_subscription(
                PointOfInterest3DStamped,
                topic,
                lambda m, p=pid: self._position_cb(p, m),
                10,
            )
            self.get_logger().info(f'Tracking person {pid!r} (track_id={self._id_map[pid]})')

        for pid in removed:
            sub = self._subs.pop(pid, None)
            if sub:
                self.destroy_subscription(sub)
            self._latest.pop(pid, None)
            self.get_logger().info(f'Lost person {pid!r}')

        self._active_ids = new_ids

    def _position_cb(self, person_id: str, msg: PointOfInterest3DStamped):
        self._latest[person_id] = msg


    def _publish_cb(self):
        out = TrackedAgents()
        out.header.stamp = self.get_clock().now().to_msg()
        out.header.frame_id = self._default_frame

        for pid, pos in list(self._latest.items()):
            tracked = TrackedAgent()
            tracked.track_id = self._id_map.get(pid, 0)
            tracked.type = AgentType.HUMAN
            tracked.name = pid
            tracked.state = TrackedAgent.MOVING

            pose = Pose()
            pose.position.x = float(pos.x)
            pose.position.y = float(pos.y)
            pose.position.z = float(pos.z)
            pose.orientation.w = 1.0

            segment = TrackedSegment()
            segment.type = TrackedSegmentType.TORSO
            segment.pose.pose = pose
            # segment.twist left zero — CoHAN computes velocity internally

            tracked.segments = [segment]
            out.agents.append(tracked)

        self._pub.publish(out)


def main():
    rclpy.init()
    node = HriToCohanBridge()
    try:
        rclpy.spin(node)
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
