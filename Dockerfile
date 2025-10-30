ARG OS_VERSION=9.3
FROM rockylinux/rockylinux:${OS_VERSION}

RUN dnf -y install --allowerasing rpm-build tar gzip curl file createrepo_c && \
    dnf clean all

WORKDIR /workspace

# 모든 빌드 스크립트 복사
COPY build-helmfile-bundle.sh /workspace/
COPY download-k8s-rpms.sh /workspace/
COPY build-all-and-repo.sh /workspace/
RUN chmod +x /workspace/*.sh

# 통합 빌드 스크립트 실행 (K8s 다운로드 + 커스텀 빌드 + createrepo)
CMD ["/bin/bash", "-c", "/workspace/build-all-and-repo.sh"]

