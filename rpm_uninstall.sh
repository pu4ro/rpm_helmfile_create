#!/bin/bash

PKG="helmfile-bundle"

echo "== helmfile 번들 패키지, 링크, 디렉토리 전체 삭제 =="

# 1. rpm 패키지 이름으로 삭제 (실패해도 무시)
sudo rpm -e "$PKG" 2>/dev/null || echo "⚠️  패키지 $PKG 삭제 실패 또는 이미 삭제됨"

# 2. 심볼릭 링크/실행파일 삭제
sudo rm -f /usr/local/bin/helmfile /usr/local/bin/helm

# 3. 번들 디렉토리 삭제
sudo rm -rf /opt/helmfile-bundle

echo "🧹 helmfile 번들 관련 모든 파일 정리 완료"

