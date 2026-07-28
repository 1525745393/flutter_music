# 登录模块修复 - 实施计划

## [ ] Task 1: 修复登录请求多格式 fallback + 完善重定向处理
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 在 `SynologyAuthApi.login()` 中实现三种请求格式 fallback：POST JSON → POST form-urlencoded → GET query
  - 完善重定向处理：支持多次重定向（最多 5 次）、相对路径解析、循环重定向保护
  - 保持请求方法（POST）和请求体在重定向过程中不丢失
- **Acceptance Criteria Addressed**: AC-1, AC-2
- **Test Requirements**:
  - `programmatic` TR-1.1: 三种请求格式按优先级依次尝试，第一种成功即返回
  - `programmatic` TR-1.2: 重定向时保持 POST 方法和请求体
  - `programmatic` TR-1.3: 支持相对路径重定向（如 `/webapi/entry.cgi`）
  - `programmatic` TR-1.4: 超过 5 次重定向抛出明确错误
  - `programmatic` TR-1.5: 循环重定向（A→B→A）被检测并抛出错误
- **Notes**: 核心修复，直接影响登录成功率

## [ ] Task 2: 抽取登录成功保存逻辑 + 2FA QuickConnect 支持
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 将登录成功后的保存逻辑（sid、did、synoToken、apiInfo、serverUrl）抽取为私有方法 `_saveLoginResult()`
  - 在 `submitTwoFactorCode()` 中添加 QuickConnect ID 解析支持
  - 优化错误信息，多地址失败时只显示最相关的 1-2 条错误
- **Acceptance Criteria Addressed**: AC-4, AC-5, AC-6
- **Test Requirements**:
  - `programmatic` TR-2.1: 普通登录和 2FA 登录均调用同一保存方法
  - `programmatic` TR-2.2: 2FA 第二步使用 QuickConnect ID 时能正确解析地址
  - `human-judgement` TR-2.3: 多地址失败时错误信息简洁，不超过 2 行
- **Notes**: 代码质量优化 + 功能修复

## [ ] Task 3: 实现 2FA 验证码输入 Dialog
- **Priority**: high
- **Depends On**: Task 2
- **Description**: 
  - 在登录页面添加 2FA 验证码输入 Dialog
  - 使用 `AlertDialog` + `TextField` 实现
  - 支持取消和提交操作
  - 提交后调用 `submitTwoFactorCode` 方法
  - 加载状态显示和错误提示
- **Acceptance Criteria Addressed**: AC-3
- **Test Requirements**:
  - `programmatic` TR-3.1: 2FA 异常时弹出验证码对话框
  - `programmatic` TR-3.2: 取消按钮关闭对话框并返回登录表单
  - `programmatic` TR-3.3: 输入验证码后提交，成功则跳转主页
  - `human-judgement` TR-3.4: Dialog 样式符合 Material Design 规范
- **Notes**: UI 功能，使用 StatefulWidget 管理 Dialog 状态
