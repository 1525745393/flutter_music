# 登录模块修复 - Product Requirement Document

## Overview
- **Summary**: 修复群晖音乐播放器登录功能，解决 POST JSON 请求兼容性问题、完善重定向处理、实现 2FA 验证码输入界面、修复 2FA QuickConnect 支持
- **Purpose**: 确保用户能够通过 QuickConnect ID 或直接地址成功登录群晖 NAS，支持两步验证流程
- **Target Users**: 使用群晖 NAS 的音乐播放器用户

## Goals
- 登录请求支持多种格式（POST JSON、POST form、GET query），提高兼容性
- 重定向处理完善（支持多次重定向、相对路径、循环保护）
- 实现 2FA 验证码输入界面
- 2FA 第二步支持 QuickConnect ID 解析
- 代码结构优化，减少重复逻辑

## Non-Goals (Out of Scope)
- 不新增 OAuth / SSO 登录方式
- 不修改现有数据持久化方案（仍使用 shared_preferences）
- 不重构整个状态管理架构
- 不添加生物识别登录（指纹/面容）
- 不修改媒体库相关功能

## Background & Context
- 当前登录 API 改为 POST + application/json 后，部分 NAS 版本或 QuickConnect 中继可能不兼容
- Dio 默认自动重定向会将 POST 转为 GET，导致请求体丢失
- 代码中已有 2FA 相关逻辑（异常类、提交方法），但 UI 层面缺少验证码输入
- 2FA 提交时未处理 QuickConnect ID 解析，可能导致第二步失败

## Functional Requirements
- **FR-1**: 登录请求支持多种格式 fallback（POST JSON → POST form → GET query）
- **FR-2**: 完善重定向处理，支持多次重定向、相对路径解析、循环重定向保护
- **FR-3**: 实现 2FA 验证码输入对话框/页面
- **FR-4**: 2FA 第二步支持 QuickConnect ID 解析
- **FR-5**: 抽取登录成功后的保存逻辑，减少代码重复

## Non-Functional Requirements
- **NFR-1**: 登录失败时错误信息简洁，不超过 2 行
- **NFR-2**: 重定向最多跟随 5 次，防止无限循环
- **NFR-3**: 2FA 输入界面符合 Material Design 规范
- **NFR-4**: 代码修改遵循项目现有命名和结构规范

## Constraints
- **Technical**: Flutter + Dart + Riverpod，不引入新依赖
- **Business**: 向后兼容现有用户数据（会话、设备 ID 等）
- **Dependencies**: dio、shared_preferences、flutter_riverpod

## Assumptions
- 群晖 Auth API 同时支持 GET、POST form、POST JSON 三种方式
- QuickConnect 中继可能导致 2-3 次重定向
- 大多数用户使用 QuickConnect ID 登录

## Acceptance Criteria

### AC-1: 多格式登录请求 fallback
- **Given**: 用户输入正确的服务器地址、账号和密码
- **When**: 点击登录按钮
- **Then**: 系统依次尝试 POST JSON → POST form-urlencoded → GET query，任一成功即登录成功
- **Verification**: `programmatic`
- **Notes**: 优先级按此顺序，POST JSON 优先尝试

### AC-2: 完善的重定向处理
- **Given**: 登录请求遇到 3xx 重定向
- **When**: 服务器返回重定向响应
- **Then**: 系统手动跟随重定向，保持 POST 方法和请求体，支持相对路径解析，最多 5 次重定向
- **Verification**: `programmatic`
- **Notes**: 超过最大重定向次数应抛出明确错误

### AC-3: 2FA 验证码输入界面
- **Given**: 登录返回 403 错误（需要两步验证）
- **When**: 用户看到"需要两步验证"的提示
- **Then**: 弹出验证码输入对话框，用户输入验证码后自动提交
- **Verification**: `human-judgment`
- **Notes**: 界面应包含取消按钮，支持返回重新输入账号密码

### AC-4: 2FA 支持 QuickConnect
- **Given**: 用户使用 QuickConnect ID 登录且开启了两步验证
- **When**: 输入验证码并提交
- **Then**: 第二步验证也通过 QuickConnect 解析后的地址发送请求
- **Verification**: `programmatic`

### AC-5: 登录成功逻辑复用
- **Given**: 登录成功（普通登录或 2FA 登录）
- **When**: 保存会话信息
- **Then**: 通过统一的私有方法保存 sid、did、synoToken、apiInfo 等信息
- **Verification**: `programmatic`

### AC-6: 错误信息简洁
- **Given**: 登录失败（多个候选地址均失败）
- **When**: 显示错误信息
- **Then**: 错误信息简洁清晰，不超过 2 行，包含最相关的错误原因
- **Verification**: `human-judgment`

## Open Questions
- [ ] 是否需要记住 2FA 设备（已有 device_id 机制，但未确认 UI 反馈）
- [ ] 2FA 输入界面用 Dialog 还是单独页面（Dialog 更轻量，推荐）
