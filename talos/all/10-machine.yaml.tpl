---
machine:
  install:
    disk: {{ .Node.Data.installDisk }}
  kubelet:
    extraArgs:
      image-gc-high-threshold: "68"
      image-gc-low-threshold: "60"
    extraConfig:
      shutdownGracePeriod: 120s
      shutdownGracePeriodCriticalPods: 60s
  files:
    - path: /etc/cri/conf.d/20-customization.part
      op: create
      content: |-
{{- if eq .Node.Host "kube5" }}
        [plugins."io.containerd.cri.v1.runtime"]
          default_runtime_name = "nvidia"
        [plugins."io.containerd.cri.v1.runtime".containerd.runtimes.nvidia]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.cri.v1.runtime".containerd.runtimes.nvidia.options]
            BinaryName = "/usr/local/bin/nvidia-container-runtime"
{{- end }}
        [plugins."io.containerd.cri.v1.images"]
          discard_unpacked_layers = false
    - op: overwrite
      path: /etc/nfsmount.conf
      permissions: 0o644
      content: |-
        [ NFSMount_Global_Options ]
        nfsvers=4.2
        hard=True
        nconnect=16
        noatime=True
  features:
    hostDNS:
      enabled: true
      resolveMemberNames: true
  kernel:
    modules:
{{- if eq .Node.Host "kube5" }}
      - name: nvidia
      - name: nvidia_uvm
      - name: nvidia_drm
      - name: nvidia_modeset
{{- end }}
      - name: dm_thin_pool
      - name: drbd
        parameters:
          - usermode_helper=disabled
      - name: drbd_transport_tcp
      - name: nvme_tcp
      - name: vfio_pci
      - name: uio_pci_generic
  sysctls:
    vm.nr_hugepages: 0
