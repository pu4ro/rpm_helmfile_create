#!/bin/bash
set -euo pipefail

# Kubernetes 버전 설정
KUBE_VERSION="${KUBE_VERSION:-1.27.16}"
KUBE_MAJOR_MINOR=$(echo "$KUBE_VERSION" | cut -d. -f1,2)

# 현재 시스템 아키텍처 감지
ARCH=$(uname -m)

# 작업 디렉토리 설정
WORKDIR="/tmp/k8s-rpms"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

echo "======================================"
echo "  Kubernetes + containerd RPM 다운로드"
echo "======================================"
echo "Kubernetes 버전: $KUBE_VERSION"
echo "아키텍처: $ARCH"
echo ""

# Kubernetes 공식 yum 저장소 설정
echo "[1/4] Kubernetes 공식 yum 저장소 설정 중..."
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${KUBE_MAJOR_MINOR}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${KUBE_MAJOR_MINOR}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# Docker 공식 yum 저장소 설정
echo "[2/4] Docker 공식 yum 저장소 설정 중 (containerd.io)..."
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# yum 캐시 업데이트
dnf clean all
dnf makecache
echo ""

# 패키지와 의존성 다운로드
echo "[3/4] Kubernetes 패키지 및 의존성 다운로드 중..."
echo "  - kubeadm-${KUBE_VERSION}"
echo "  - kubelet-${KUBE_VERSION}"
echo "  - kubectl-${KUBE_VERSION}"
echo ""

cd "$WORKDIR"

# dnf download 또는 yumdownloader 사용 (가능한 것 자동 선택)
if command -v dnf &> /dev/null && dnf help download &> /dev/null 2>&1; then
  echo "dnf download 사용 중..."
  # --disableexcludes=kubernetes 옵션으로 exclude 무시하고 다운로드
  # --resolve 옵션으로 의존성까지 모두 다운로드
  # --arch 옵션으로 현재 시스템 아키텍처만 다운로드
  dnf download --disableexcludes=kubernetes --resolve --arch=${ARCH} \
    kubeadm-${KUBE_VERSION}-* \
    kubelet-${KUBE_VERSION}-* \
    kubectl-${KUBE_VERSION}-*
elif command -v yumdownloader &> /dev/null; then
  echo "yumdownloader 사용 중..."
  # --disableexcludes=kubernetes 옵션으로 exclude 무시하고 다운로드
  # --resolve 옵션으로 의존성까지 모두 다운로드
  # --archlist 옵션으로 현재 시스템 아키텍처만 다운로드
  yumdownloader --disableexcludes=kubernetes --resolve --archlist=${ARCH} \
    kubeadm-${KUBE_VERSION}-* \
    kubelet-${KUBE_VERSION}-* \
    kubectl-${KUBE_VERSION}-*
else
  echo "ERROR: dnf download 또는 yumdownloader를 찾을 수 없습니다."
  echo "다음 중 하나를 설치해주세요:"
  echo "  - dnf-plugins-core (dnf download 제공)"
  echo "  - yum-utils (yumdownloader 제공)"
  exit 1
fi

echo ""
echo "[4/4] containerd, ansible 및 관련 패키지 다운로드 중..."
# containerd.io와 container-selinux 다운로드
if command -v dnf &> /dev/null && dnf help download &> /dev/null 2>&1; then
  echo "  - containerd.io (Docker 레포)"
  dnf download --resolve --arch=${ARCH} containerd.io
  echo "  - container-selinux"
  dnf download --resolve --arch=noarch container-selinux
  echo "  - ansible-core"
  dnf download --resolve --arch=${ARCH} ansible-core
elif command -v yumdownloader &> /dev/null; then
  echo "  - containerd.io (Docker 레포)"
  yumdownloader --resolve --archlist=${ARCH} containerd.io
  echo "  - container-selinux"
  yumdownloader --resolve --archlist=noarch container-selinux
  echo "  - ansible-core"
  yumdownloader --resolve --archlist=${ARCH} ansible-core
fi

echo ""
echo "RPM 파일을 /workspace로 복사 중..."
cp "$WORKDIR"/*.rpm /workspace/

echo ""
echo "다운로드된 패키지 요약:"
echo "- Kubernetes: kubectl, kubelet, kubeadm, cri-tools, kubernetes-cni"
echo "- Container Runtime: containerd.io, container-selinux"
echo "- Automation: ansible-core"
echo ""
ls -lh /workspace/kube*.rpm /workspace/cri-tools*.rpm /workspace/kubernetes-cni*.rpm /workspace/containerd*.rpm /workspace/container-selinux*.rpm /workspace/ansible*.rpm 2>/dev/null || true

echo ""
echo "패키지 다운로드 완료!"
