# 登录模块修复 - 验证清单

## Task 1: 修复登录请求多格式 fallback + 完善重定向处理
- [ ] 登录请求依次尝试 POST JSON → POST form-urlencoded → GET query
- [ ] 第一种格式成功后立即返回，不再尝试后续格式
- [ ] 重定向时保持 POST 方法和请求体不丢失
- [ ] 支持相对路径重定向（如 `/webapi/entry.cgi`）
- [ ] 最多跟随 5 次重定向，超过则抛出错误
- [ ] 循环重定向（A→B→A）被检测并抛出错误
- [ ] 代码注释说明 fallback 策略和重定向处理逻辑
- [ ] 修改仅影响登录请求，不影响其他 API 调用

## Task 2: 抽取登录成功保存逻辑 + 2FA QuickConnect 支持
- [ ] 普通登录和 2FA 登录均调用统一的 `_saveLoginResult()` 方法
- [ ] 保存内容包括：sid、did、synoToken、apiInfo、serverUrl
- [ ] 2FA 第二步提交时调用 `_resolveServerUrlsIfNeeded()` 解析地址
- [ ] 2FA 提交失败时错误信息正确传递
- [ ] 多地址登录失败时错误信息简洁，不超过 2 行
- [ ] 错误信息包含最相关的错误原因（如"账号密码错误"而非一堆地址）
- [ ] 没有破坏原有会话恢复逻辑

## Task 3: 实现 2FA 验证码输入 Dialog
- [ ] 捕获到 TwoFactorAuthException 时弹出验证码 Dialog
- [ ] Dialog 包含标题、验证码输入框、取消按钮、确定按钮
- [ ] 取消按钮关闭 Dialog 并返回登录表单
- [ ] 确定按钮提交验证码，显示加载状态
- [ ] 验证成功后关闭 Dialog 并跳转到主页
- [ ] 验证失败时在 Dialog 内显示错误信息
- [ ] 输入框自动获取焦点，弹出数字键盘
- [ ] Dialog 样式符合 Material Design 和应用整体风格

## 整体验证
- [ ] 运行 flutter analyze 无 lint 错误
- [ ] 运行 flutter test 现有测试全部通过
- [ ] 代码命名符合项目规范（snake_case 文件名、camelCase 变量）
- [ ] 关键逻辑有中文注释说明
- [ ] 没有在日志中打印密码等敏感信息
- [ ] 向后兼容现有用户数据（会话、设备 ID 等）
