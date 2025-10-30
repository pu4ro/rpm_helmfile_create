ARG OS_VERSION=9.3
FROM rockylinux/rockylinux:${OS_VERSION}

RUN dnf -y install --allowerasing rpm-build tar gzip curl file createrepo_c && \
    dnf clean all

WORKDIR /workspace

COPY build-helmfile-bundle.sh /workspace/
RUN chmod +x /workspace/build-helmfile-bundle.sh

# 빌드 끝난 뒤에도 컨테이너가 종료되지 않게 함
CMD ["/bin/bash", "-c", "/workspace/build-helmfile-bundle.sh"]

