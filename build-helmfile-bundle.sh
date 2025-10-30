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
echo "참고: kubectl, kubelet, kubeadm은 공식 yum 저장소에서 다운로드됩니다"
echo ""
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR/SOURCES" "$SPECDIR" "$WORKDIR/RPMS"

# ============================================
# 1. helmfile-bundle 패키지 빌드
# ============================================
echo ""
echo "[1/4] helmfile-bundle 빌드 중..."
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
echo "[2/4] nerdctl 빌드 중..."
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
Requires:       glibc

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
echo "[3/4] buildkit 빌드 중..."
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
Requires:       glibc

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

%files
/usr/local/bin/buildkitd
/usr/local/bin/buildctl

%changelog
* $(date '+%a %b %d %Y') Admin <admin@example.com> - ${BUILDKIT_VERSION}-1
- buildkit v${BUILDKIT_VERSION}
EOF

rpmbuild --define "_topdir $WORKDIR" -ba "$SPECDIR/buildkit.spec"

# ============================================
# 4. k9s 패키지 빌드
# ============================================
echo ""
echo "[4/4] k9s 빌드 중..."
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
