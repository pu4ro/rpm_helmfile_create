#!/bin/bash
set -euo pipefail

echo "=========================================="
echo "  전체 패키지 빌드 및 레포지토리 생성"
echo "=========================================="
echo ""

# ============================================
# 1단계: Kubernetes 공식 패키지 다운로드
# ============================================
echo "[단계 1/3] Kubernetes 공식 패키지 다운로드 중..."
echo ""
/workspace/download-k8s-rpms.sh

echo ""
echo "=========================================="
echo ""

# ============================================
# 2단계: 커스텀 RPM 패키지 빌드
# ============================================
echo "[단계 2/3] 커스텀 패키지 빌드 중..."
echo ""
/workspace/build-helmfile-bundle.sh

echo ""
echo "=========================================="
echo ""

# ============================================
# 3단계: YUM 레포지토리 생성
# ============================================
echo "[단계 3/3] YUM 레포지토리 생성 중..."
echo ""

REPO_DIR="/workspace/yum-repo"
rm -rf "$REPO_DIR"
mkdir -p "$REPO_DIR/Packages"

# 모든 RPM 파일을 레포지토리 디렉토리로 복사
echo "RPM 파일을 레포지토리로 복사 중..."
find /workspace -maxdepth 1 -name "*.rpm" -exec cp -v {} "$REPO_DIR/Packages/" \;

echo ""
echo "createrepo 실행 중..."
cd "$REPO_DIR"
createrepo_c .

echo ""
echo "=========================================="
echo "  모든 작업 완료!"
echo "=========================================="
echo ""
echo "레포지토리 위치: $REPO_DIR"
echo ""
echo "생성된 패키지 목록:"
ls -lh "$REPO_DIR/Packages/" | grep "\.rpm$"
echo ""
echo "총 $(ls -1 "$REPO_DIR/Packages/"*.rpm 2>/dev/null | wc -l)개의 RPM 패키지"
echo ""
echo "=========================================="
echo "레포지토리 사용 방법:"
echo "=========================================="
echo ""
echo "1. 로컬 사용 (동일 시스템):"
echo "   sudo tee /etc/yum.repos.d/custom-local.repo <<EOF"
echo "   [custom-local]"
echo "   name=Custom Local Repository"
echo "   baseurl=file://$REPO_DIR"
echo "   enabled=1"
echo "   gpgcheck=0"
echo "   EOF"
echo ""
echo "2. HTTP 서버로 제공:"
echo "   cd $REPO_DIR && python3 -m http.server 8080"
echo "   그 다음 클라이언트에서:"
echo "   sudo tee /etc/yum.repos.d/custom-remote.repo <<EOF"
echo "   [custom-remote]"
echo "   name=Custom Remote Repository"
echo "   baseurl=http://<서버IP>:8080/"
echo "   enabled=1"
echo "   gpgcheck=0"
echo "   EOF"
echo ""
echo "3. 패키지 설치:"
echo "   sudo dnf clean all"
echo "   sudo dnf install -y kubeadm kubelet kubectl helmfile-bundle nerdctl buildkit k9s"
echo ""
echo "=========================================="
