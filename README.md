# helmfile-bundle RPM 오프라인 빌더

이 프로젝트는 **컨테이너 환경에서 helmfile + helm + helm-diff 플러그인**을
오프라인에서 설치 가능한 RPM 패키지로 한번에 묶어주는 자동 빌드 도구입니다.

또한 생성된 RPM 패키지들로 **YUM/DNF 레포지토리**를 구성할 수 있습니다.

## 구성 파일

* `Dockerfile` : 빌드용 컨테이너 환경 정의 (Rocky Linux 9, createrepo_c 포함)
* `build-helmfile-bundle.sh` : rpm 패키지 생성 및 복사 스크립트 (컨테이너 내부에서 실행)
* `make-helmfile-bundle.sh` : 전체 프로세스 자동화 실행 스크립트 (호스트에서 실행)
* `Makefile` : Make 기반 빌드 및 레포지토리 생성 자동화

---

## 요구사항

* Docker (컨테이너 빌드를 위해 필요)
* bash (스크립트 실행을 위해 필요)
* make (Makefile 사용 시 필요, 선택사항)
* 인터넷 연결 (바이너리 및 플러그인 다운로드 시 필요)

---

## 사용법

### 방법 1: Makefile 사용 (권장)

**빌드 및 레포지토리 한 번에 생성**
```bash
make
# 또는
make all
```

**RPM만 빌드**
```bash
make build
```

**기존 RPM으로 레포지토리만 생성**
```bash
make repo
# 또는
make createrepo
```

**NVIDIA 드라이버 다운로드**
```bash
# 기본 버전 다운로드 (570.124.06)
make nvidia

# 특정 버전 다운로드
make nvidia NVIDIA_DRIVER_VERSION=550.90.07

# 환경변수로 설정
export NVIDIA_DRIVER_VERSION=550.90.07
export NVIDIA_BASE_URL=https://us.download.nvidia.com/tesla
make nvidia
```

다운로드된 드라이버는 `yum-repo/Packages/` 디렉토리에 저장됩니다.

**특정 OS 버전으로 빌드**
```bash
# Rocky Linux 9.4로 빌드
make OS_VERSION=9.4

# Rocky Linux 8.9로 빌드
make OS_VERSION=8.9 build

# 환경 변수로도 설정 가능
OS_VERSION=9.4 make
```

**정리**
```bash
make clean      # RPM 파일만 삭제
make clean-all  # RPM + 레포지토리 모두 삭제
```

**도움말**
```bash
make help
```

### 방법 2: 쉘 스크립트 직접 실행

1. **실행 권한을 부여합니다.**

   ```bash
   chmod +x build-helmfile-bundle.sh make-helmfile-bundle.sh
   ```

2. **실행합니다.**

   ```bash
   # 기본 버전 (Rocky Linux 9.3)
   ./make-helmfile-bundle.sh

   # 특정 OS 버전 지정
   OS_VERSION=9.4 ./make-helmfile-bundle.sh
   OS_VERSION=8.9 ./make-helmfile-bundle.sh
   ```

3. **rpm 결과 파일이 현재 디렉토리에 생성됩니다.**

   ```
   helmfile-bundle-0.169.1-1.el9.x86_64.rpm
   kubectl-1.27.16-1.el9.x86_64.rpm
   kubelet-1.27.16-1.el9.x86_64.rpm
   kubeadm-1.27.16-1.el9.x86_64.rpm
   nerdctl-1.6.0-1.el9.x86_64.rpm
   buildkit-0.12.2-1.el9.x86_64.rpm
   k9s-0.32.5-1.el9.x86_64.rpm
   ```

---

## 환경 변수로 버전 지정 (선택)

### OS 버전 지정

Rocky Linux 버전을 지정할 수 있습니다 (기본값: 9.3):

```bash
# Makefile 사용
make OS_VERSION=9.4
make OS_VERSION=8.9 build

# 쉘 스크립트 사용
OS_VERSION=9.4 ./make-helmfile-bundle.sh
OS_VERSION=8.9 ./make-helmfile-bundle.sh
```

### 컴포넌트 버전 지정

빌드 스크립트 내에서 정의된 컴포넌트 버전을 변경하려면:

```bash
HELMFILE_VERSION=0.162.0 HELM_VERSION=3.14.0 make build
HELMFILE_VERSION=0.162.0 HELM_VERSION=3.14.0 ./make-helmfile-bundle.sh
```

---

## YUM/DNF 레포지토리 생성 및 사용

### 레포지토리 생성

RPM 빌드 후, `make repo` 명령으로 YUM/DNF 레포지토리를 생성할 수 있습니다:

```bash
make repo
```

생성된 레포지토리는 `yum-repo/` 디렉토리에 위치합니다:
```
yum-repo/
├── Packages/
│   ├── helmfile-bundle-0.169.1-1.el9.x86_64.rpm
│   ├── kubectl-1.27.16-1.el9.x86_64.rpm
│   └── ...
└── repodata/
    ├── repomd.xml
    ├── primary.xml.gz
    └── ...
```

### 레포지토리 사용

#### 로컬 파일 시스템으로 사용

동일 시스템에서 사용하는 경우:

```bash
sudo tee /etc/yum.repos.d/helmfile-local.repo <<EOF
[helmfile-local]
name=Helmfile Bundle Local Repository
baseurl=file:///root/rpm_helmfile_create/yum-repo
enabled=1
gpgcheck=0
EOF

sudo dnf clean all
sudo dnf install helmfile-bundle kubectl kubelet kubeadm
```

#### HTTP 서버로 제공

네트워크를 통해 다른 시스템에서 사용하는 경우:

**서버 측:**
```bash
cd yum-repo
python3 -m http.server 8080
```

**클라이언트 측:**
```bash
sudo tee /etc/yum.repos.d/helmfile-remote.repo <<EOF
[helmfile-remote]
name=Helmfile Bundle Remote Repository
baseurl=http://<서버IP>:8080/
enabled=1
gpgcheck=0
EOF

sudo dnf clean all
sudo dnf install helmfile-bundle kubectl kubelet kubeadm nerdctl buildkit k9s
```

## 개별 RPM 설치

레포지토리를 사용하지 않고 개별 RPM 파일로 설치할 수도 있습니다:

```bash
sudo rpm -ivh helmfile-bundle-0.169.1-1.el9.x86_64.rpm
sudo rpm -ivh kubectl-1.27.16-1.el9.x86_64.rpm
# ... 기타 패키지
```

설치 후 다음 명령으로 정상 설치 여부를 확인할 수 있습니다:

```bash
helmfile version
helm version
kubectl version --client
ls /opt/helmfile-bundle/plugins/helm-diff/
```

---

## 빌드 구조 및 결과물

* **/opt/helmfile-bundle** 아래에 helmfile, helm, helm-diff plugin이 함께 설치됨
* **/usr/local/bin/helmfile**, **/usr/local/bin/helm** 심볼릭 링크 생성

---

## 트러블슈팅

* rpm 파일이 안 만들어지는 경우, 컨테이너에서 직접 빌드 스크립트를 실행해 로그와 에러 메시지를 확인하세요.

  ```bash
  docker run -it --rm -v "$PWD":/workspace helmfile-bundle-builder /bin/bash
  cd /workspace
  ./build-helmfile-bundle.sh
  ```
* 파일명이 다를 경우, 스크립트에서 rpm 생성 경로를 자동 감지합니다.
* 바이너리 다운로드 실패 시 인터넷 연결을 확인하세요.

---

## 참고

* rpm에서 디버그 심볼 추출로 인한 에러를 방지하려면 SPEC 파일 상단에 `%global debug_package %{nil}`을 추가합니다.
* 기타 문의나 확장 요청은 언제든 이슈를 남겨 주세요.

---


