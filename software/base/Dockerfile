FROM ubuntu:devel as ubuntu-build
RUN DEBIAN_FRONTEND=noninteractive \
  apt update && \
  DEBIAN_FRONTEND=noninteractive \
  apt -y install linux-image-4.13.0-32-lowlatency

FROM scratch as rootfs
COPY --from=ubuntu-build /boot /boot
COPY --from=ubuntu-build /lib/modules /lib/modules
COPY --from=busybox /bin /bin
#COPY --from=busybox /usr/bin /usr/bin
#COPY --from=busybox /sbin /sbin
COPY --from=busybox /usr/sbin /usr/sbin
COPY --from=docker /usr/local/bin /usr/bin
