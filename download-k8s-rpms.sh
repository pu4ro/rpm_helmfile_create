#!/bin/bash
set -euo pipefail

# Kubernetes 버전 설정
KUBE_VERSION="${KUBE_VERSION:-1.27.16}"
KUBE_MAJOR_MINOR=$(echo "$KUBE_VERSION" | cut -d. -f1,2)

# 작업 디렉토리 설정
WORKDIR="/tmp/k8s-rpms"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

echo "======================================"
echo "  Kubernetes 공식 RPM 다운로드"
echo "======================================"
echo "버전: $KUBE_VERSION"
echo ""

# Kubernetes 공식 yum 저장소 설정
echo "[1/3] Kubernetes 공식 yum 저장소 설정 중..."
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${KUBE_MAJOR_MINOR}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${KUBE_MAJOR_MINOR}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# yum 캐시 업데이트
dnf clean all
dnf makecache
echo ""

# 패키지와 의존성 다운로드
echo "[2/3] Kubernetes 패키지 및 의존성 다운로드 중..."
echo "  - kubeadm-${KUBE_VERSION}"
echo "  - kubelet-${KUBE_VERSION}"
echo "  - kubectl-${KUBE_VERSION}"
echo ""

cd "$WORKDIR"

# --disableexcludes=kubernetes 옵션으로 exclude 무시하고 다운로드
# --resolve 옵션으로 의존성까지 모두 다운로드
dnf download --disableexcludes=kubernetes --resolve \
  kubeadm-${KUBE_VERSION}-* \
  kubelet-${KUBE_VERSION}-* \
  kubectl-${KUBE_VERSION}-*

echo ""
echo "[3/3] RPM 파일을 /workspace로 복사 중..."
cp "$WORKDIR"/*.rpm /workspace/

echo ""
echo "다운로드된 Kubernetes RPM 파일:"
ls -lh /workspace/kube*.rpm /workspace/cri-tools*.rpm /workspace/kubernetes-cni*.rpm 2>/dev/null || true

echo ""
echo "Kubernetes 패키지 다운로드 완료!"
