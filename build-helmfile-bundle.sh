#!/bin/bash
set -euo pipefail

HELMFILE_VERSION="${HELMFILE_VERSION:-0.169.1}"
HELM_VERSION="${HELM_VERSION:-3.14.4}"
HELM_DIFF_VERSION="${HELM_DIFF_VERSION:-3.9.7}"

ARCH=amd64
OS=linux
NAME=helmfile-bundle
VERSION=${HELMFILE_VERSION}
WORKDIR=/tmp/rpmbuild
BUNDLE="$WORKDIR/SOURCES/${NAME}-${VERSION}"
SPECDIR="$WORKDIR/SPECS"

echo "== 빌드 시작 =="
rm -rf "$WORKDIR"
mkdir -p "$BUNDLE/plugins/helm-diff" "$SPECDIR"

# 1. helmfile 다운로드 및 압축 해제
echo "[*] helmfile 다운로드"
curl -fsSL -o "$BUNDLE/helmfile.tar.gz" "https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_linux_${ARCH}.tar.gz"
tar xzf "$BUNDLE/helmfile.tar.gz" -C "$BUNDLE"
rm "$BUNDLE/helmfile.tar.gz"
chmod +x "$BUNDLE/helmfile"
if ! file "$BUNDLE/helmfile" | grep -q 'ELF 64-bit'; then
  echo "❌ helmfile 바이너리 다운로드/압축 해제 실패! URL, 버전, 네트워크를 확인하세요."
  head "$BUNDLE/helmfile"
  exit 1
fi

# 2. helm 다운로드 및 압축 해제
echo "[*] helm 다운로드"
curl -fsSL -o "$BUNDLE/helm.tar.gz" "https://get.helm.sh/helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz"
tar xzf "$BUNDLE/helm.tar.gz" -C "$BUNDLE"
mv "$BUNDLE/${OS}-${ARCH}/helm" "$BUNDLE/helm"
rm -rf "$BUNDLE/helm.tar.gz" "$BUNDLE/${OS}-${ARCH}"
chmod +x "$BUNDLE/helm"
if ! file "$BUNDLE/helm" | grep -q 'ELF 64-bit'; then
  echo "❌ helm 바이너리 다운로드/압축 해제 실패! URL, 버전, 네트워크를 확인하세요."
  head "$BUNDLE/helm"
  exit 1
fi

# 3. helm-diff 다운로드 및 압축 해제
echo "[*] helm-diff 플러그인 다운로드"
curl -fsSL -o "$BUNDLE/plugins/helm-diff/helm-diff.tgz" "https://github.com/databus23/helm-diff/releases/download/v${HELM_DIFF_VERSION}/helm-diff-linux-amd64.tgz"
tar xzf "$BUNDLE/plugins/helm-diff/helm-diff.tgz" -C "$BUNDLE/plugins/helm-diff"
rm "$BUNDLE/plugins/helm-diff/helm-diff.tgz"
DIFF_BIN=$(find "$BUNDLE/plugins/helm-diff" -type f -executable | head -n 1)
if [ -z "$DIFF_BIN" ] || ! file "$DIFF_BIN" | grep -q 'ELF 64-bit'; then
  echo "❌ helm-diff 플러그인 바이너리 다운로드/압축 해제 실패! URL, 버전, 네트워크를 확인하세요."
  head "$DIFF_BIN"
  exit 1
fi

# 4. 소스 tarball 생성
cd "$WORKDIR/SOURCES"
tar czvf "${NAME}-${VERSION}.tar.gz" "${NAME}-${VERSION}"

# 5. SPEC 파일 작성
cat <<EOF > "$SPECDIR/${NAME}.spec"
%global debug_package %{nil}
Name:           ${NAME}
Version:        ${VERSION}
Release:        1%{?dist}
Summary:        Offline bundle for helmfile (includes helm and helm-diff plugin)
License:        MIT
Source0:        %{name}-%{version}.tar.gz
BuildArch:      x86_64
Requires:       glibc

%description
Offline bundle for helmfile v${HELMFILE_VERSION}. Includes:
- helm v${HELM_VERSION}
- helm-diff plugin v${HELM_DIFF_VERSION}
Works fully offline.

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
* Thu Jun 13 2024 Your Name <your@email.com> - ${VERSION}-1
- helmfile v${HELMFILE_VERSION} offline bundle
EOF

# 6. rpm 빌드
echo "[*] rpmbuild 실행"
rpmbuild --define "_topdir $WORKDIR" -ba "$SPECDIR/${NAME}.spec"

# 7. rpm 파일 복사 (가장 최신 rpm 자동 탐색)
RPM_FILE=$(find $WORKDIR/RPMS -type f -name "*.rpm" | sort | tail -n 1)
if [[ ! -f "$RPM_FILE" ]]; then
  echo "❌ RPM 파일을 찾을 수 없습니다: $WORKDIR/RPMS"
  exit 1
fi

cp "$RPM_FILE" /workspace/
echo "[*] 빌드 완료! 파일이 복사되었습니다:"
echo "  ./$(basename "$RPM_FILE")"

