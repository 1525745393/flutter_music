#!/usr/bin/env python3
"""设置 GitHub Actions Secrets 的脚本"""

import base64
import sys
import json
import urllib.request
import urllib.error

# PyNaCl 用于 Box 加密
from nacl import encoding, public

import os

# 配置
REPO_OWNER = os.environ.get("GITHUB_REPO_OWNER", "1525745393")
REPO_NAME = os.environ.get("GITHUB_REPO_NAME", "flutter_music")
GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")

if not GITHUB_TOKEN:
    print("错误: 请设置 GITHUB_TOKEN 环境变量")
    sys.exit(1)

API_BASE = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}"


def api_request(path, method="GET", data=None):
    """发送 GitHub API 请求"""
    url = f"{API_BASE}{path}"
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json",
        "Content-Type": "application/json",
    }

    body = json.dumps(data).encode("utf-8") if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req) as response:
            return response.status, json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode("utf-8"))


def encrypt_secret(public_key_str: str, secret_value: str) -> str:
    """使用 GitHub 公钥加密密钥值"""
    public_key = public.PublicKey(
        public_key_str.encode("utf-8"), encoding.Base64Encoder()
    )
    sealed_box = public.SealedBox(public_key)
    encrypted = sealed_box.encrypt(secret_value.encode("utf-8"))
    return base64.b64encode(encrypted).decode("utf-8")


def get_public_key():
    """获取仓库的 Secrets 公钥"""
    status, data = api_request("/actions/secrets/public-key")
    if status != 200:
        print(f"获取公钥失败: {status} {data}")
        sys.exit(1)
    return data["key_id"], data["key"]


def set_secret(secret_name: str, secret_value: str, key_id: str, public_key_str: str):
    """设置单个 Secret"""
    encrypted_value = encrypt_secret(public_key_str, secret_value)
    payload = {
        "encrypted_value": encrypted_value,
        "key_id": key_id,
    }
    status, data = api_request(
        f"/actions/secrets/{secret_name}", method="PUT", data=payload
    )
    if status in (201, 204):
        action = "创建" if status == 201 else "更新"
        print(f"✅ {action} Secret: {secret_name}")
        return True
    else:
        print(f"❌ 设置 Secret {secret_name} 失败: {status} {data}")
        return False


def list_secrets():
    """列出所有 Secrets（只显示名称，不显示值）"""
    status, data = api_request("/actions/secrets")
    if status == 200:
        secrets = data.get("secrets", [])
        print(f"\n当前仓库共有 {len(secrets)} 个 Secrets:")
        for s in secrets:
            print(f"  - {s['name']} (更新于: {s['updated_at']})")
        return secrets
    else:
        print(f"获取 Secrets 列表失败: {status} {data}")
        return []


def main():
    # 读取 keystore 文件并转为 base64
    with open("android/app-release.jks", "rb") as f:
        keystore_base64 = base64.b64encode(f.read()).decode("utf-8")

    # 要设置的 Secrets
    secrets = {
        "KEYSTORE_BASE64": keystore_base64,
        "STORE_PASSWORD": "test123456",
        "KEY_PASSWORD": "test123456",
        "KEY_ALIAS": "release",
    }

    print("获取 GitHub 仓库公钥...")
    key_id, public_key_str = get_public_key()
    print(f"公钥 ID: {key_id}")
    print()

    print("开始设置 Secrets...")
    success_count = 0
    for name, value in secrets.items():
        if set_secret(name, value, key_id, public_key_str):
            success_count += 1

    print()
    print(f"完成: 成功设置 {success_count}/{len(secrets)} 个 Secrets")

    # 列出当前所有 Secrets 进行验证
    list_secrets()


if __name__ == "__main__":
    main()
