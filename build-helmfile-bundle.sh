#!/bin/bash
set -euo pipefail

# 버전 설정
HELMFILE_VERSION="${HELMFILE_VERSION:-0.169.1}"
HELM_VERSION="${HELM_VERSION:-3.14.4}"
HELM_DIFF_VERSION="${HELM_DIFF_VERSION:-3.9.7}"
KUBE_VERSION="${KUBE_VERSION:-1.27.16}"
NERDCTL_VERSION="${NERDCTL_VERSION:-1.6.0}"
BUILDKIT_VERSION="${BUILDKIT_VERSION:-0.12.2}"
K9S_VERSION="${K9S_VERSION:-$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep -oP '"tag_name": "\K[^"]+' | sed 's/^v//')}"

ARCH=amd64
OS=linux
WORKDIR=/tmp/rpmbuild
SPECDIR="$WORKDIR/SPECS"

echo "======================================"
echo "  개별 컴포넌트 RPM 빌드 시작"
echo "======================================"
echo "참고:"
echo "  - kubectl, kubelet, kubeadm: Kubernetes 공식 레포에서 다운로드"
echo "  - containerd.io: Docker 공식 레포에서 다운로드"
echo "  - ansible-core: Rocky Linux 레포에서 다운로드"
echo "  - helmfile, nerdctl, buildkit, k9s, ansible-collections: 커스텀 빌드"
echo ""
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR/SOURCES" "$SPECDIR" "$WORKDIR/RPMS"

# ============================================
# 1. helmfile-bundle 패키지 빌드
# ============================================
echo ""
echo "[1/5] helmfile-bundle 빌드 중..."
BUNDLE_NAME="helmfile-bundle"
BUNDLE_DIR="$WORKDIR/SOURCES/${BUNDLE_NAME}-${HELMFILE_VERSION}"
mkdir -p "$BUNDLE_DIR/plugins/helm-diff"

# helmfile 다운로드
echo "  - helmfile 다운로드"
curl -fsSL -o "$BUNDLE_DIR/helmfile.tar.gz" "https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_linux_${ARCH}.tar.gz"
tar xzf "$BUNDLE_DIR/helmfile.tar.gz" -C "$BUNDLE_DIR"
rm "$BUNDLE_DIR/helmfile.tar.gz"
chmod +x "$BUNDLE_DIR/helmfile"

# helm 다운로드
echo "  - helm 다운로드"
curl -fsSL -o "$BUNDLE_DIR/helm.tar.gz" "https://get.helm.sh/helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz"
tar xzf "$BUNDLE_DIR/helm.tar.gz" -C "$BUNDLE_DIR"
mv "$BUNDLE_DIR/${OS}-${ARCH}/helm" "$BUNDLE_DIR/helm"
rm -rf "$BUNDLE_DIR/helm.tar.gz" "$BUNDLE_DIR/${OS}-${ARCH}"
chmod +x "$BUNDLE_DIR/helm"

# helm-diff 다운로드
echo "  - helm-diff 플러그인 다운로드"
curl -fsSL -o "$BUNDLE_DIR/plugins/helm-diff/helm-diff.tgz" "https://github.com/databus23/helm-diff/releases/download/v${HELM_DIFF_VERSION}/helm-diff-linux-amd64.tgz"
tar xzf "$BUNDLE_DIR/plugins/helm-diff/helm-diff.tgz" -C "$BUNDLE_DIR/plugins/helm-diff"
rm "$BUNDLE_DIR/plugins/helm-diff/helm-diff.tgz"

# tarball 생성
cd "$WORKDIR/SOURCES"
tar czf "${BUNDLE_NAME}-${HELMFILE_VERSION}.tar.gz" "${BUNDLE_NAME}-${HELMFILE_VERSION}"

# spec 파일 생성
cat <<EOF > "$SPECDIR/${BUNDLE_NAME}.spec"
%global debug_package %{nil}
Name:           ${BUNDLE_NAME}
Version:        ${HELMFILE_VERSION}
Release:        1%{?dist}
Summary:        Offline bundle for helmfile with helm and helm-diff plugin
License:        MIT
Source0:        %{name}-%{version}.tar.gz
BuildArch:      x86_64
Requires:       glibc

%description
Offline bundle for helmfile. Includes:
- helmfile v${HELMFILE_VERSION}
- helm v${HELM_VERSION}
- helm-diff plugin v${HELM_DIFF_VERSION}

%prep
%setup -q

%build

%install
mkdir -p %{buildroot}/opt/helmfile-bundle
cp -a * %{buildroot}/opt/helmfile-bundle/
mkdir -p %{buildroot}/usr/local/bin
ln -sf /opt/helmfile-bundle/helmfile %{buildroot}/usr/local/bin/helmfile
ln -sf /opt/helmfile-bundle/helm %{buildroot}/usr/local/bin/helm

%files
/opt/helmfile-bundle/*
/usr/local/bin/helmfile
/usr/local/bin/helm

%changelog
* $(date '+%a %b %d %Y') Admin <admin@example.com> - ${HELMFILE_VERSION}-1
- helmfile bundle v${HELMFILE_VERSION}
EOF

rpmbuild --define "_topdir $WORKDIR" -ba "$SPECDIR/${BUNDLE_NAME}.spec"

# ============================================
# 2. nerdctl 패키지 빌드
# ============================================
echo ""
echo "[2/5] ansible-collections 빌드 중..."

ANSIBLE_VERSION="1.0.0"
ANSIBLE_COLLECTIONS_DIR="$WORKDIR/SOURCES/ansible-collections-${ANSIBLE_VERSION}"
mkdir -p "$ANSIBLE_COLLECTIONS_DIR/collections"

echo "  - 필수 collections 다운로드 중..."
# ansible-galaxy를 사용하기 위해 임시로 ansible-core 설치
dnf install -y ansible-core -q 2>&1 | tail -3

# 주요 collections 다운로드
cd "$ANSIBLE_COLLECTIONS_DIR/collections"
echo "    * community.general"
ansible-galaxy collection download community.general -p . 2>&1 | grep -v "^$"
echo "    * community.docker"
ansible-galaxy collection download community.docker -p . 2>&1 | grep -v "^$"
echo "    * kubernetes.core"
ansible-galaxy collection download kubernetes.core -p . 2>&1 | grep -v "^$"
echo "    * ansible.posix"
ansible-galaxy collection download ansible.posix -p . 2>&1 | grep -v "^$"
echo "    * community.crypto"
ansible-galaxy collection download community.crypto -p . 2>&1 | grep -v "^$"

cd "$WORKDIR/SOURCES"
tar czf "ansible-collections-${ANSIBLE_VERSION}.tar.gz" "ansible-collections-${ANSIBLE_VERSION}"

cat <<EOF > "$SPECDIR/ansible-collections.spec"
%global debug_package %{nil}
%global __brp_mangle_shebangs %{nil}
%global __brp_python_bytecompile %{nil}
Name:           ansible-collections
Version:        ${ANSIBLE_VERSION}
Release:        1%{?dist}
Summary:        Essential Ansible collections for offline use
License:        GPL-3.0-or-later
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch
Requires:       ansible-core

%description
Essential Ansible collections for offline environments including:
- community.general: General purpose modules and plugins
- community.docker: Docker management
- kubernetes.core: Kubernetes management
- ansible.posix: POSIX system modules
- community.crypto: Cryptography utilities

%prep
%setup -q

%build

%install
mkdir -p %{buildroot}/usr/share/ansible/collections/ansible_collections
cd collections
for tarball in *.tar.gz; do
    tar xzf "\$tarball" -C %{buildroot}/usr/share/ansible/collections/ansible_collections
done
# 불필요한 파일 제거 (테스트, CI 설정 등)
find %{buildroot}/usr/share/ansible/collections/ansible_collections -name ".git*" -exec rm -rf {} + 2>/dev/null || true
find %{buildroot}/usr/share/ansible/collections/ansible_collections -name ".azure-pipelines" -exec rm -rf {} + 2>/dev/null || true
find %{buildroot}/usr/share/ansible/collections/ansible_collections -name "tests" -type d -exec rm -rf {} + 2>/dev/null || true
find %{buildroot}/usr/share/ansible/collections/ansible_collections -name ".yamllint*" -delete 2>/dev/null || true
find %{buildroot}/usr/share/ansible/collections/ansible_collections -name ".ansible-lint*" -delete 2>/dev/null || true
find %{buildroot}/usr/share/ansible/collections/ansible_collections -name ".flake8" -delete 2>/dev/null || true
find %{buildroot}/usr/share/ansible/collections/ansible_collections -name ".mypy.ini" -delete 2>/dev/null || true
find %{buildroot}/usr/share/ansible/collections/ansible_collections -name ".pylintrc" -delete 2>/dev/null || true
find %{buildroot}/usr/share/ansible/collections/ansible_collections -name ".isort.cfg" -delete 2>/dev/null || true

%files
/usr/share/ansible/collections/ansible_collections

%changelog
* $(date '+%a %b %d %Y') Admin <admin@example.com> - ${ANSIBLE_VERSION}-1
- Essential Ansible collections bundle for offline use
EOF

rpmbuild --define "_topdir $WORKDIR" -ba "$SPECDIR/ansible-collections.spec"

# ============================================
# 3. nerdctl 패키지 빌드
# ============================================
echo ""
echo "[3/5] nerdctl 빌드 중..."
NERDCTL_DIR="$WORKDIR/SOURCES/nerdctl-${NERDCTL_VERSION}"
mkdir -p "$NERDCTL_DIR"

echo "  - nerdctl 다운로드"
curl -fsSL -o "$NERDCTL_DIR/nerdctl.tar.gz" "https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-${NERDCTL_VERSION}-linux-${ARCH}.tar.gz"
tar xzf "$NERDCTL_DIR/nerdctl.tar.gz" -C "$NERDCTL_DIR"
rm "$NERDCTL_DIR/nerdctl.tar.gz"
chmod +x "$NERDCTL_DIR/nerdctl"

cd "$WORKDIR/SOURCES"
tar czf "nerdctl-${NERDCTL_VERSION}.tar.gz" "nerdctl-${NERDCTL_VERSION}"

cat <<EOF > "$SPECDIR/nerdctl.spec"
%global debug_package %{nil}
Name:           nerdctl
Version:        ${NERDCTL_VERSION}
Release:        1%{?dist}
Summary:        Docker-compatible CLI for containerd
License:        Apache-2.0
Source0:        %{name}-%{version}.tar.gz
BuildArch:      x86_64
Requires:       glibc containerd.io

%description
nerdctl is a Docker-compatible CLI for containerd.

%prep
%setup -q

%build

%install
mkdir -p %{buildroot}/usr/local/bin
cp nerdctl %{buildroot}/usr/local/bin/nerdctl
chmod +x %{buildroot}/usr/local/bin/nerdctl

%files
/usr/local/bin/nerdctl

%changelog
* $(date '+%a %b %d %Y') Admin <admin@example.com> - ${NERDCTL_VERSION}-1
- nerdctl v${NERDCTL_VERSION}
EOF

rpmbuild --define "_topdir $WORKDIR" -ba "$SPECDIR/nerdctl.spec"

# ============================================
# 3. buildkit 패키지 빌드
# ============================================
echo ""
echo "[4/5] buildkit 빌드 중..."
BUILDKIT_DIR="$WORKDIR/SOURCES/buildkit-${BUILDKIT_VERSION}"
mkdir -p "$BUILDKIT_DIR"

echo "  - buildkit 다운로드"
curl -fsSL -o "$BUILDKIT_DIR/buildkit.tar.gz" "https://github.com/moby/buildkit/releases/download/v${BUILDKIT_VERSION}/buildkit-v${BUILDKIT_VERSION}.linux-${ARCH}.tar.gz"
tar xzf "$BUILDKIT_DIR/buildkit.tar.gz" -C "$BUILDKIT_DIR" --strip-components=1
rm "$BUILDKIT_DIR/buildkit.tar.gz"
chmod +x "$BUILDKIT_DIR/buildkitd" "$BUILDKIT_DIR/buildctl"

cd "$WORKDIR/SOURCES"
tar czf "buildkit-${BUILDKIT_VERSION}.tar.gz" "buildkit-${BUILDKIT_VERSION}"

cat <<EOF > "$SPECDIR/buildkit.spec"
%global debug_package %{nil}
Name:           buildkit
Version:        ${BUILDKIT_VERSION}
Release:        1%{?dist}
Summary:        Concurrent, cache-efficient, and Dockerfile-agnostic builder toolkit
License:        Apache-2.0
Source0:        %{name}-%{version}.tar.gz
BuildArch:      x86_64
Requires:       glibc containerd.io

%description
BuildKit is a toolkit for converting source code to build artifacts in an efficient, expressive and repeatable manner.

%prep
%setup -q

%build

%install
mkdir -p %{buildroot}/usr/local/bin
cp buildkitd %{buildroot}/usr/local/bin/buildkitd
cp buildctl %{buildroot}/usr/local/bin/buildctl
chmod +x %{buildroot}/usr/local/bin/buildkitd
chmod +x %{buildroot}/usr/local/bin/buildctl

# buildkit 설정 파일
mkdir -p %{buildroot}/etc/buildkit
cat <<EOFC > %{buildroot}/etc/buildkit/buildkitd.toml
[worker.oci]
  enabled = false

[worker.containerd]
  enabled = true
  namespace = "k8s.io"
EOFC

# systemd 서비스 파일
mkdir -p %{buildroot}/usr/lib/systemd/system
cat <<EOFS > %{buildroot}/usr/lib/systemd/system/buildkit.service
[Unit]
Description=BuildKit
Documentation=https://github.com/moby/buildkit
Requires=containerd.service
After=containerd.service

[Service]
Type=notify
ExecStart=/usr/local/bin/buildkitd --config /etc/buildkit/buildkitd.toml
Restart=always
RestartSec=5
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOFS

%files
/usr/local/bin/buildkitd
/usr/local/bin/buildctl
/etc/buildkit/buildkitd.toml
/usr/lib/systemd/system/buildkit.service

%post
systemctl daemon-reload

%changelog
* $(date '+%a %b %d %Y') Admin <admin@example.com> - ${BUILDKIT_VERSION}-1
- buildkit v${BUILDKIT_VERSION} with containerd support and systemd service
EOF

rpmbuild --define "_topdir $WORKDIR" -ba "$SPECDIR/buildkit.spec"

# ============================================
# 4. k9s 패키지 빌드
# ============================================
echo ""
echo "[5/5] k9s 빌드 중..."
K9S_DIR="$WORKDIR/SOURCES/k9s-${K9S_VERSION}"
mkdir -p "$K9S_DIR"

echo "  - k9s 다운로드"
curl -fsSL -o "$K9S_DIR/k9s.tar.gz" "https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_${ARCH}.tar.gz"
tar xzf "$K9S_DIR/k9s.tar.gz" -C "$K9S_DIR"
rm "$K9S_DIR/k9s.tar.gz"
chmod +x "$K9S_DIR/k9s"

cd "$WORKDIR/SOURCES"
tar czf "k9s-${K9S_VERSION}.tar.gz" "k9s-${K9S_VERSION}"

cat <<EOF > "$SPECDIR/k9s.spec"
%global debug_package %{nil}
Name:           k9s
Version:        ${K9S_VERSION}
Release:        1%{?dist}
Summary:        Kubernetes CLI To Manage Your Clusters In Style
License:        Apache-2.0
Source0:        %{name}-%{version}.tar.gz
BuildArch:      x86_64
Requires:       glibc

%description
K9s is a terminal based UI to interact with your Kubernetes clusters.

%prep
%setup -q

%build

%install
mkdir -p %{buildroot}/usr/local/bin
cp k9s %{buildroot}/usr/local/bin/k9s
chmod +x %{buildroot}/usr/local/bin/k9s

%files
/usr/local/bin/k9s

%changelog
* $(date '+%a %b %d %Y') Admin <admin@example.com> - ${K9S_VERSION}-1
- k9s v${K9S_VERSION}
EOF

rpmbuild --define "_topdir $WORKDIR" -ba "$SPECDIR/k9s.spec"

# ============================================
# 빌드 완료 - RPM 파일 복사
# ============================================
echo ""
echo "======================================"
echo "  모든 RPM 빌드 완료!"
echo "======================================"

# 모든 RPM 파일을 workspace로 복사
find "$WORKDIR/RPMS" -type f -name "*.rpm" -exec cp {} /workspace/ \;

echo ""
echo "생성된 RPM 패키지 목록:"
ls -lh /workspace/*.rpm

echo ""
echo "빌드 완료!"
