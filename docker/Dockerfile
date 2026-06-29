FROM eprosima/vulcanexus:humble-desktop

WORKDIR /home
ENV EDITOR=nano
ENV XDG_RUNTIME_DIR=/tmp
ENV SHELL=/bin/bash
ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-c"]

RUN apt-get update && apt-get install -y \
    wget git bash-completion build-essential sudo nano \
    python3-vcstool python3-rosdep python3-colcon-common-extensions python3-pip \
    ros-humble-navigation2 ros-humble-nav2-bringup ros-humble-nav2-costmap-2d \
    ros-humble-nav2-navfn-planner ros-humble-nav2-smac-planner \
    ros-humble-behaviortree-cpp-v3 \
    ros-dev-tools \
    libboost-all-dev libsuitesparse-dev libeigen3-dev \
    libopenblas-dev \
    qtbase5-dev libcholmod3 cmake \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/RainerKuemmerle/g2o.git /tmp/g2o \
    && cd /tmp/g2o && mkdir build && cd build \
    && cmake .. -DBUILD_SHARED_LIBS=ON \
    && make -j$(nproc) && make install \
    && ldconfig && rm -rf /tmp/g2o

RUN rosdep init || true && rosdep update

RUN mkdir -p /home/cohan_ws/src
WORKDIR /home/cohan_ws/src

RUN git clone https://github.com/sphanit/CoHAN-Nav2.git

RUN git clone -b humble https://github.com/rst-tu-dortmund/costmap_converter.git

RUN git clone -b add-points-of-interest-3d https://github.com/andvatistas/hri_msgs.git

WORKDIR /home/cohan_ws

RUN . /opt/vulcanexus/humble/setup.bash \
    && rosdep install --from-paths src --ignore-src -r -y || true

RUN . /opt/vulcanexus/humble/setup.bash \
    && colcon build \
        --packages-skip cohan_nav2_tutorial \
        --symlink-install \
        --cmake-args -DCMAKE_BUILD_TYPE=Release \
    && echo "Build complete"


RUN echo "source /opt/vulcanexus/humble/setup.bash" >> /root/.bashrc \
    && echo "source /home/cohan_ws/install/setup.bash" >> /root/.bashrc

RUN mkdir -p /config /launch

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--help"]
