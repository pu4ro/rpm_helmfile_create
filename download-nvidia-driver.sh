#!/bin/bash
set -e

# NVIDIA 드라이버 다운로드 스크립트
# 환경변수로 버전 관리

# 기본값 설정
NVIDIA_BASE_URL="${NVIDIA_BASE_URL:-https://us.download.nvidia.com/tesla}"
NVIDIA_DRIVER_VERSION="${NVIDIA_DRIVER_VERSION:-570.124.06}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-/workspace/yum-repo/Packages}"

echo "======================================"
echo "NVIDIA 드라이버 다운로드"
echo "======================================"
echo "Base URL: $NVIDIA_BASE_URL"
echo "Driver Version: $NVIDIA_DRIVER_VERSION"
echo "Download Directory: $DOWNLOAD_DIR"
echo ""

# 다운로드 디렉토리 생성
mkdir -p "$DOWNLOAD_DIR"
cd "$DOWNLOAD_DIR"

# 파일명 구성
DRIVER_FILE="NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}.run"
DOWNLOAD_URL="${NVIDIA_BASE_URL}/${NVIDIA_DRIVER_VERSION}/${DRIVER_FILE}"

# 이미 다운로드된 파일이 있는지 확인
if [ -f "$DRIVER_FILE" ]; then
    echo "✓ NVIDIA 드라이버가 이미 존재합니다: $DRIVER_FILE"
    FILE_SIZE=$(ls -lh "$DRIVER_FILE" | awk '{print $5}')
    echo "  파일 크기: $FILE_SIZE"
    echo ""
    echo "다시 다운로드하려면 파일을 삭제하고 스크립트를 재실행하세요."
else
    echo "NVIDIA 드라이버 다운로드 중..."
    echo "URL: $DOWNLOAD_URL"
    echo ""

    if curl -fSsl -O "$DOWNLOAD_URL"; then
        echo ""
        echo "✓ 다운로드 완료!"
        FILE_SIZE=$(ls -lh "$DRIVER_FILE" | awk '{print $5}')
        echo "  파일: $DRIVER_FILE"
        echo "  크기: $FILE_SIZE"
        chmod +x "$DRIVER_FILE"
        echo "  실행 권한 부여 완료"
    else
        echo ""
        echo "✗ 다운로드 실패!"
        echo "  URL을 확인하세요: $DOWNLOAD_URL"
        exit 1
    fi
fi

echo ""
echo "======================================"
echo "다운로드 완료!"
echo "======================================"
echo ""
echo "설치 방법:"
echo "  sudo bash $DRIVER_FILE"
echo ""
echo "환경변수 설정 예시:"
echo "  export NVIDIA_DRIVER_VERSION=570.124.06"
echo "  export NVIDIA_BASE_URL=https://us.download.nvidia.com/tesla"
echo "  ./download-nvidia-driver.sh"
