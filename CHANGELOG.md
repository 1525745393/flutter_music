## [1.5.1](https://github.com/1525745393/flutter_music/compare/v1.5.0...v1.5.1) (2026-07-06)


### Bug Fixes

* 修复直连IP地址无法登录的问题 ([05505b3](https://github.com/1525745393/flutter_music/commit/05505b321a4585a7dc73b65721c164defababbcc))

# [1.5.0](https://github.com/1525745393/flutter_music/compare/v1.4.3...v1.5.0) (2026-07-06)


### Bug Fixes

* 修复CI分析错误（synoToken参数传递） ([d357e15](https://github.com/1525745393/flutter_music/commit/d357e1547239f2480dc195bc1f6bfd260033cca1))


### Features

* 对照DSM官方登录文档全面优化Auth体系 ([c278aa4](https://github.com/1525745393/flutter_music/commit/c278aa4903bd3f91f5dfc918f12ca6e8159d5a18))
* 生成项目Code Wiki文档 ([c5f4e23](https://github.com/1525745393/flutter_music/commit/c5f4e230aea878979ec1ce68a5dcb133753f5765))

## [1.4.3](https://github.com/1525745393/flutter_music/compare/v1.4.2...v1.4.3) (2026-07-06)


### Bug Fixes

* Auth登录改回GET请求 ([83636b9](https://github.com/1525745393/flutter_music/commit/83636b94af02509204eec5762c4bb5a6e9041c46))

## [1.4.2](https://github.com/1525745393/flutter_music/compare/v1.4.1...v1.4.2) (2026-07-06)


### Bug Fixes

* 修复请求方式错误，严格对照文档 ([bfeff7d](https://github.com/1525745393/flutter_music/commit/bfeff7db3bab1b20ae882d7a74450bbdb13c7dd1))

## [1.4.1](https://github.com/1525745393/flutter_music/compare/v1.4.0...v1.4.1) (2026-07-06)


### Bug Fixes

* 对照AudioStation接口文档全面修复API接口 ([3597eaa](https://github.com/1525745393/flutter_music/commit/3597eaae48b5fb4ef3d692128e3f2253d441ab64))

# [1.4.0](https://github.com/1525745393/flutter_music/compare/v1.3.0...v1.4.0) (2026-07-06)


### Bug Fixes

* 修复登录相关问题，对照AudioStation接口文档 ([e79978d](https://github.com/1525745393/flutter_music/commit/e79978d7cda801a92d2ca10b50c1a59a85bdc70c))


### Features

* 生成项目Code Wiki文档 ([d4c3db3](https://github.com/1525745393/flutter_music/commit/d4c3db3dffa67d7aa7587dfd1fb2fbdec772175e))

# [1.3.0](https://github.com/1525745393/flutter_music/compare/v1.2.7...v1.3.0) (2026-07-06)


### Bug Fixes

* 修复CI分析警告和错误 ([74219c2](https://github.com/1525745393/flutter_music/commit/74219c24260749f8911760fc5320e98f4d9d6929))


### Features

* 生成项目Code Wiki文档 ([e184806](https://github.com/1525745393/flutter_music/commit/e18480640fec141859d94857ac21b39271c8553f))

## [1.2.7](https://github.com/1525745393/flutter_music/compare/v1.2.6...v1.2.7) (2026-07-06)


### Bug Fixes

* 为checkout步骤添加GH_PAT认证，确保semantic-release可推送 ([deddb2b](https://github.com/1525745393/flutter_music/commit/deddb2b8d3f43bc9797a8d6a965210c9415bc2c4))
* 修复Release工作流失败问题 ([34b6cf1](https://github.com/1525745393/flutter_music/commit/34b6cf162f6c772de728e619d9fc686f6ac5b581))
* 修复音乐库403错误，优化错误处理 ([d916c95](https://github.com/1525745393/flutter_music/commit/d916c952cf056ab69b9bac85c97961a670e036c9))

## [1.2.6](https://github.com/1525745393/flutter_music/compare/v1.2.5...v1.2.6) (2026-07-05)


### Bug Fixes

* 修复 DioClient badCertificateCallback 类型不匹配，使用 IOHttpClientAdapter ([79a789e](https://github.com/1525745393/flutter_music/commit/79a789eebf91060252df463286f251bf05f09ef6))
* 修正 IOHttpClientAdapter createHttpClient 签名，移除 SecurityContext 参数 ([f82af74](https://github.com/1525745393/flutter_music/commit/f82af74e7eeb9ab2e742f60dd63cb4d276f7b80a))

## [1.2.5](https://github.com/1525745393/flutter_music/compare/v1.2.4...v1.2.5) (2026-07-05)


### Bug Fixes

* 完整修复 QuickConnect 登录的 7 个关键问题 ([6194d0e](https://github.com/1525745393/flutter_music/commit/6194d0e982834abb73de78aa58d67537a89fcf1d))

## [1.2.4](https://github.com/1525745393/flutter_music/compare/v1.2.3...v1.2.4) (2026-07-05)


### Bug Fixes

* 修改 QuickConnect 请求流程，先 GET 获取 control_host ([08c6b4e](https://github.com/1525745393/flutter_music/commit/08c6b4ea51f0ed0d249bdeb490bea298b6614425))

## [1.2.3](https://github.com/1525745393/flutter_music/compare/v1.2.2...v1.2.3) (2026-07-05)


### Bug Fixes

* 改进响应解析，支持 String 类型响应和 HTML 检测 ([0c53de8](https://github.com/1525745393/flutter_music/commit/0c53de82428e644a36fec39be3f916e8ef39faa0))

## [1.2.2](https://github.com/1525745393/flutter_music/compare/v1.2.1...v1.2.2) (2026-07-05)


### Bug Fixes

* 修复 QuickConnect API 请求格式，使用正确的抓包参数 ([395c547](https://github.com/1525745393/flutter_music/commit/395c547007c67f4a66306b2dd6e2d98bc21f5ddf))

## [1.2.1](https://github.com/1525745393/flutter_music/compare/v1.2.0...v1.2.1) (2026-07-05)


### Bug Fixes

* QuickConnect 错误信息显示所有区域失败详情 ([c0eeec5](https://github.com/1525745393/flutter_music/commit/c0eeec5c389397ee3f3ce53d4dd99ecfc9d370f5))

# [1.2.0](https://github.com/1525745393/flutter_music/compare/v1.1.1...v1.2.0) (2026-07-05)


### Features

* QuickConnect 增加中国区支持和自动区域检测 ([cdcf120](https://github.com/1525745393/flutter_music/commit/cdcf12067e8c95e0ea1ab9e06b403623176eb7c6))

## [1.1.1](https://github.com/1525745393/flutter_music/compare/v1.1.0...v1.1.1) (2026-07-05)


### Bug Fixes

* 修复 QuickConnect ID 解析和错误提示问题 ([02f236a](https://github.com/1525745393/flutter_music/commit/02f236ac5cc64a04b36333d7e6844ed1b0537d35))

# [1.1.0](https://github.com/1525745393/flutter_music/compare/v1.0.3...v1.1.0) (2026-07-05)


### Features

* 添加完整 QuickConnect 协议支持 ([a01e8b5](https://github.com/1525745393/flutter_music/commit/a01e8b5597cdb14f1db81e5426768f086ed8e1ff))

## [1.0.3](https://github.com/1525745393/flutter_music/compare/v1.0.2...v1.0.3) (2026-07-05)


### Bug Fixes

* 修复 Dio 响应类型转换错误，处理非 JSON 响应 ([40138af](https://github.com/1525745393/flutter_music/commit/40138afdb303b3dba8459c2aa491d2ffd3e2061c))

## [1.0.2](https://github.com/1525745393/flutter_music/compare/v1.0.1...v1.0.2) (2026-07-05)


### Bug Fixes

* 添加网络权限和安全配置，优化错误提示 ([981cd40](https://github.com/1525745393/flutter_music/commit/981cd408696e1d170c7953a76108ce9b94013b57))

## [1.0.1](https://github.com/1525745393/flutter_music/compare/v1.0.0...v1.0.1) (2026-07-05)


### Bug Fixes

* 修复 build.gradle.kts 中 java.io.File 引用错误 ([062a9c6](https://github.com/1525745393/flutter_music/commit/062a9c617aa8152d46655b0e09869ae3020bc1ad))

# 1.0.0 (2026-07-05)


### Bug Fixes

* CI 格式检查改为非阻塞模式 ([e88b36b](https://github.com/1525745393/flutter_music/commit/e88b36b1f3eb6377024daef2e5311f314419ef5a))
* 使用最新稳定版 Flutter 以满足依赖的 Dart SDK 要求 ([4a447fd](https://github.com/1525745393/flutter_music/commit/4a447fd26c90cac01f70ecc5e13e94f583747412))
* 更新 semantic-release branches 配置为 master ([4acf88f](https://github.com/1525745393/flutter_music/commit/4acf88fd9ed31ef5918e480c68f0de7f55f25b69))
* 降低 Dart SDK 版本要求以兼容 CI 环境 ([788463c](https://github.com/1525745393/flutter_music/commit/788463c65c53a46971179b86ffc17b2c3c3911c4))


### Features

* Add project analysis documentation and implement audio playback features ([0ed8d49](https://github.com/1525745393/flutter_music/commit/0ed8d49db6fd8508dcec908d2e6339ee9e448df6))
* 添加 CI/CD 自动化发布工作流 ([4153fde](https://github.com/1525745393/flutter_music/commit/4153fded5051720a30260b445e029fb886b4d9c6))
