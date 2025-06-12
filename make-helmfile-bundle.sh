#!/bin/bash
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
DOCKER_IMAGE=helmfile-bundle-builder

echo "=== [1/3] 빌드 컨테이너 이미지 생성 ==="
docker build -t $DOCKER_IMAGE -f "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR"

echo
echo "=== [2/3] 컨테이너 내 빌드 스크립트 실행 및 컨테이너 유지(자동종료X) ==="
docker run -it --rm -v "$PWD":/workspace $DOCKER_IMAGE

echo
echo "=== [3/3] 결과물 ==="

echo
echo "rpm 파일을 오프라인 환경에 복사하여 다음과 같이 설치하세요:"
echo "sudo rpm -ivh helmfile-bundle-*-1.x86_64.rpm"
