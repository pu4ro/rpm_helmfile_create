FROM rockylinux/rockylinux:9.3

RUN dnf -y install rpm-build tar gzip curl file && \
    dnf clean all

WORKDIR /workspace

COPY build-helmfile-bundle.sh /workspace/
RUN chmod +x /workspace/build-helmfile-bundle.sh

# 빌드 끝난 뒤에도 컨테이너가 종료되지 않게 함
CMD ["/bin/bash", "-c", "/workspace/build-helmfile-bundle.sh"]

