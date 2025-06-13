# helmfile-bundle RPM 오프라인 빌더

이 프로젝트는 **컨테이너 환경에서 helmfile + helm + helm-diff 플러그인**을
오프라인에서 설치 가능한 RPM 패키지로 한번에 묶어주는 자동 빌드 도구입니다.

## 구성 파일

* `Dockerfile` : 빌드용 컨테이너 환경 정의 (Rocky Linux 9)
* `build-helmfile-bundle.sh` : rpm 패키지 생성 및 복사 스크립트 (컨테이너 내부에서 실행)
* `make-helmfile-bundle.sh` : 전체 프로세스 자동화 실행 스크립트 (호스트에서 실행)

---

## 요구사항

* Docker (컨테이너 빌드를 위해 필요)
* bash (스크립트 실행을 위해 필요)
* 인터넷 연결 (바이너리 및 플러그인 다운로드 시 필요)

---

## 사용법

1. **세 파일을 같은 디렉토리에 둡니다.**

   * `Dockerfile`
   * `build-helmfile-bundle.sh`
   * `make-helmfile-bundle.sh`

2. **실행 권한을 부여합니다.**

   ```bash
   chmod +x build-helmfile-bundle.sh make-helmfile-bundle.sh
   ```

3. **실행합니다.**

   ```bash
   ./make-helmfile-bundle.sh
   ```

4. **rpm 결과 파일이 현재 디렉토리에 생성됩니다.**

   ```
   helmfile-bundle-0.169.1-1.x86_64.rpm
   ```

   > 컨테이너는 빌드 후 자동으로 종료되지 않으며, 필요 시 `docker ps` 및 `docker stop [컨테이너ID]`로 수동 종료 가능합니다.

---

## 환경 변수로 버전 지정 (선택)

원하는 버전으로 빌드하려면 아래처럼 환경변수를 지정해 실행할 수 있습니다.

```bash
HELMFILE_VERSION=0.162.0 HELM_VERSION=3.14.0 ./make-helmfile-bundle.sh
```

---

## 설치 및 사용

생성된 rpm 파일을 오프라인 환경에 복사한 뒤, 아래와 같이 설치합니다.

```bash
sudo rpm -ivh helmfile-bundle-0.169.1-1.x86_64.rpm
```

설치 후 다음 명령으로 정상 설치 여부를 확인할 수 있습니다:

```bash
helmfile version
helm version
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


