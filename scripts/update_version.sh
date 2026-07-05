#!/bin/bash

# 更新 Flutter 项目的 pubspec.yaml 版本号
# 用法: ./scripts/update_version.sh <新版本号>

set -e

NEW_VERSION="$1"

if [ -z "$NEW_VERSION" ]; then
  echo "错误: 请提供新版本号"
  echo "用法: $0 <新版本号>"
  exit 1
fi

# 从当前版本号中提取构建号
CURRENT_VERSION=$(grep 'version:' pubspec.yaml | head -1 | sed 's/version: //')
BUILD_NUMBER=$(echo "$CURRENT_VERSION" | grep -oP '(?<=\+)\d+' || echo "1")

# 新版本号 + 构建号 +1
NEW_BUILD=$((BUILD_NUMBER + 1))
FULL_VERSION="${NEW_VERSION}+${NEW_BUILD}"

echo "当前版本: $CURRENT_VERSION"
echo "新版本: $FULL_VERSION"

# 使用 sed 更新 pubspec.yaml 中的 version 字段
sed -i "s/^version: .*/version: ${FULL_VERSION}/" pubspec.yaml

echo "版本号已更新为: $FULL_VERSION"
