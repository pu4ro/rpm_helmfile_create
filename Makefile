.PHONY: all build build-with-k8s repo createrepo clean clean-all help

# 변수 설정
DOCKER_IMAGE = helmfile-bundle-builder
SCRIPT_DIR = $(shell pwd)
REPO_DIR = $(SCRIPT_DIR)/yum-repo
RPMS_DIR = $(SCRIPT_DIR)
OS_VERSION ?= 9.3

# 기본 타겟 (K8s 공식 패키지 포함)
all: build-with-k8s

# K8s 공식 패키지 + 커스텀 빌드 + createrepo (통합 빌드)
build-with-k8s:
	@echo "=== [1/2] 빌드 컨테이너 이미지 생성 (OS_VERSION=$(OS_VERSION)) ==="
	docker build --build-arg OS_VERSION=$(OS_VERSION) -t $(DOCKER_IMAGE) -f $(SCRIPT_DIR)/Dockerfile $(SCRIPT_DIR)
	@echo ""
	@echo "=== [2/2] K8s 다운로드 + 커스텀 빌드 + createrepo 실행 ==="
	docker run --rm -v $(SCRIPT_DIR):/workspace $(DOCKER_IMAGE)
	@echo ""
	@echo "=== 완료! ==="
	@echo ""
	@echo "생성된 레포지토리: $(REPO_DIR)"

# 커스텀 RPM만 빌드 (K8s 공식 패키지 제외)
build:
	@echo "=== [1/2] 빌드 컨테이너 이미지 생성 (OS_VERSION=$(OS_VERSION)) ==="
	docker build --build-arg OS_VERSION=$(OS_VERSION) -t $(DOCKER_IMAGE) -f $(SCRIPT_DIR)/Dockerfile $(SCRIPT_DIR)
	@echo ""
	@echo "=== [2/2] 커스텀 패키지 빌드만 실행 ==="
	docker run --rm -v $(SCRIPT_DIR):/workspace $(DOCKER_IMAGE) /bin/bash -c "/workspace/build-helmfile-bundle.sh"
	@echo ""
	@echo "=== RPM 빌드 완료 ==="
	@ls -lh $(SCRIPT_DIR)/*.rpm 2>/dev/null || echo "RPM 파일이 없습니다."

# YUM 레포지토리 생성
repo: createrepo

createrepo:
	@echo "=== YUM 레포지토리 생성 중 ==="
	@mkdir -p $(REPO_DIR)/Packages
	@echo "RPM 파일을 레포지토리 디렉토리로 복사 중..."
	@find $(RPMS_DIR) -maxdepth 1 -name "*.rpm" -exec cp -v {} $(REPO_DIR)/Packages/ \;
	@echo ""
	@echo "createrepo 실행 중..."
	docker run --rm -v $(REPO_DIR):/repo:Z $(DOCKER_IMAGE) \
		sh -c "createrepo_c /repo && ls -lh /repo/"
	@echo ""
	@echo "=== 레포지토리 생성 완료! ==="
	@echo ""
	@echo "레포지토리 위치: $(REPO_DIR)"
	@echo ""
	@echo "레포지토리 사용 방법:"
	@echo "1. 로컬 사용 (동일 시스템):"
	@echo "   sudo tee /etc/yum.repos.d/helmfile-local.repo <<EOF"
	@echo "   [helmfile-local]"
	@echo "   name=Helmfile Bundle Local Repository"
	@echo "   baseurl=file://$(REPO_DIR)"
	@echo "   enabled=1"
	@echo "   gpgcheck=0"
	@echo "   EOF"
	@echo ""
	@echo "2. HTTP 서버로 제공:"
	@echo "   cd $(REPO_DIR) && python3 -m http.server 8080"
	@echo "   그 다음 클라이언트에서:"
	@echo "   sudo tee /etc/yum.repos.d/helmfile-remote.repo <<EOF"
	@echo "   [helmfile-remote]"
	@echo "   name=Helmfile Bundle Remote Repository"
	@echo "   baseurl=http://<서버IP>:8080/"
	@echo "   enabled=1"
	@echo "   gpgcheck=0"
	@echo "   EOF"
	@echo ""
	@echo "3. 패키지 설치:"
	@echo "   sudo dnf clean all"
	@echo "   sudo dnf install helmfile-bundle kubectl kubelet kubeadm containerd.io nerdctl buildkit k9s ansible-core ansible-collections"

# RPM 파일만 정리
clean:
	@echo "RPM 파일 정리 중..."
	@rm -f $(SCRIPT_DIR)/*.rpm
	@echo "정리 완료"

# 모든 생성된 파일 정리 (RPM + 레포지토리)
clean-all: clean
	@echo "레포지토리 디렉토리 정리 중..."
	@rm -rf $(REPO_DIR)
	@echo "모든 정리 완료"

# 도움말
help:
	@echo "사용 가능한 Make 타겟:"
	@echo "  make all              - K8s 공식 패키지 다운로드 + 커스텀 빌드 + createrepo (기본값)"
	@echo "  make build-with-k8s   - K8s 공식 패키지 다운로드 + 커스텀 빌드 + createrepo (all과 동일)"
	@echo "  make build            - 커스텀 RPM 패키지만 빌드 (K8s 제외)"
	@echo "  make repo             - YUM 레포지토리 생성 (createrepo 실행)"
	@echo "  make createrepo       - repo와 동일"
	@echo "  make clean            - RPM 파일 삭제"
	@echo "  make clean-all        - RPM 파일 + 레포지토리 삭제"
	@echo "  make help             - 이 도움말 표시"
	@echo ""
	@echo "변수:"
	@echo "  OS_VERSION            - Rocky Linux 버전 (기본값: 9.3)"
	@echo ""
	@echo "예제:"
	@echo "  make                        - K8s + 커스텀 빌드 + createrepo (Rocky 9.3)"
	@echo "  make OS_VERSION=9.4         - Rocky Linux 9.4로 전체 빌드"
	@echo "  make OS_VERSION=8.9 build   - Rocky Linux 8.9로 커스텀 RPM만 빌드"
	@echo "  make repo                   - 기존 RPM으로 레포지토리 생성"
	@echo ""
	@echo "주요 특징:"
	@echo "  - kubectl, kubelet, kubeadm: Kubernetes 공식 레포에서 다운로드"
	@echo "  - containerd.io: Docker 공식 레포에서 다운로드 (Kubernetes 1.27 호환)"
	@echo "  - ansible-core: Rocky Linux 레포에서 다운로드"
	@echo "  - ansible-collections: 주요 collections 포함 (community.general, kubernetes.core 등)"
	@echo "  - 모든 의존성(cri-tools, kubernetes-cni, container-selinux 등) 포함"
	@echo "  - helmfile-bundle, nerdctl, buildkit, k9s: 커스텀 빌드"
	@echo "  - 모든 패키지는 하나의 yum 레포지토리로 통합됩니다"
	@echo ""
	@echo "환경 변수로도 설정 가능:"
	@echo "  OS_VERSION=9.4 make"
