# StackLight

A lightweight macOS menu bar app that monitors deployments, CI/CD pipelines, and pull requests across multiple services — all in one place.

[English](#english) | [中文](#中文)

---

<a id="english"></a>

## Overview

StackLight lives in your menu bar and gives you a quick glance at the status of your deployments and pull requests. No need to open dashboards or switch between tabs — just click the triangle icon.

## Features

- **Multi-service support** — Monitor deployments from Vercel, Cloudflare Pages, GitHub Actions, Netlify, Railway, Fly.io, Xcode Cloud, and TestFlight
- **GitHub Pull Requests** — Track open PRs across multiple repositories
- **Real-time polling** — Configurable refresh interval (30s – 5min)
- **Native notifications** — Get notified when a deploy fails or succeeds
- **macOS-native UI** — Settings window styled after System Settings
- **Launch at login** — Optional auto-start via macOS Login Items
- **Secure credential storage** — API tokens stored in macOS Keychain

## Supported Services

| Service | What it monitors |
|---------|-----------------|
| Vercel | Deployments |
| Cloudflare Pages | Deployments |
| GitHub Actions | Workflow runs |
| GitHub Pull Requests | Open PRs |
| Netlify | Deployments |
| Railway | Deployments |
| Fly.io | Deployments |
| Xcode Cloud | Builds |
| TestFlight | Build processing & review status |

## Requirements

- macOS 13.0+
- Swift 5.9+
- Xcode 15+ (for building)

## Build & Run

```bash
# Clone the repo
git clone https://github.com/hwangdev97/StackLight.git
cd StackLight

# Open in Xcode and run (Cmd+R)
open Package.swift
```

> **Note:** StackLight is a menu bar app (`LSUIElement`). It has no Dock icon — look for the **triangle icon** (▲) in the menu bar after launching.

## Setup

1. Launch StackLight
2. Click the ▲ icon in the menu bar → **Settings**
3. Select a service from the sidebar
4. Enter your API token / credentials
5. Click **Save**, then **Test** to verify the connection

For GitHub Pull Requests, you can add repositories one by one using the "+" button.

## Architecture

```
Sources/StackLight/
├── App/                  # App entry point, AppDelegate, AppState
├── Core/                 # Protocols, models, polling, notifications, keychain
├── Providers/            # One file per service integration
└── UI/                   # Settings view, menu bar builder
```

StackLight uses a plugin architecture — each service implements the `DeploymentProvider` protocol and is auto-registered in `ServiceRegistry`. Adding a new service is as simple as creating a new provider file.

## License

MIT

---

<a id="中文"></a>

## 概述

StackLight 是一个 macOS 菜单栏应用，用于集中监控多个平台的部署状态、CI/CD 流水线和 GitHub Pull Requests。无需打开各种仪表盘，点一下菜单栏图标即可查看。

## 功能

- **多服务支持** — 监控 Vercel、Cloudflare Pages、GitHub Actions、Netlify、Railway、Fly.io、Xcode Cloud 和 TestFlight
- **GitHub Pull Requests** — 追踪多个仓库的 open PR
- **实时轮询** — 可配置刷新间隔（30 秒 – 5 分钟）
- **原生通知** — 部署失败或成功时推送 macOS 通知
- **原生 UI** — 设置界面风格对齐 macOS 系统设置
- **开机启动** — 可选的 macOS 登录项自动启动
- **安全存储** — API 令牌保存在 macOS 钥匙串中

## 支持的服务

| 服务 | 监控内容 |
|------|---------|
| Vercel | 部署状态 |
| Cloudflare Pages | 部署状态 |
| GitHub Actions | Workflow 运行状态 |
| GitHub Pull Requests | 打开的 PR |
| Netlify | 部署状态 |
| Railway | 部署状态 |
| Fly.io | 部署状态 |
| Xcode Cloud | 构建状态 |
| TestFlight | 构建处理和审核状态 |

## 系统要求

- macOS 13.0+
- Swift 5.9+
- Xcode 15+（用于构建）

## 构建与运行

```bash
# 克隆仓库
git clone https://github.com/hwangdev97/StackLight.git
cd StackLight

# 用 Xcode 打开并运行（Cmd+R）
open Package.swift
```

> **注意：** StackLight 是菜单栏应用（`LSUIElement`），没有 Dock 图标。启动后请在菜单栏寻找 **三角形图标**（▲）。

## 配置

1. 启动 StackLight
2. 点击菜单栏的 ▲ 图标 → **Settings**
3. 在侧栏选择一个服务
4. 输入 API 令牌等凭据
5. 点击 **Save**，然后点 **Test** 验证连接

GitHub Pull Requests 支持通过 "+" 按钮逐个添加仓库。

## 项目结构

```
Sources/StackLight/
├── App/                  # 应用入口、AppDelegate、AppState
├── Core/                 # 协议、模型、轮询、通知、钥匙串管理
├── Providers/            # 每个服务一个文件
└── UI/                   # 设置界面、菜单栏构建
```

StackLight 采用插件架构 —— 每个服务实现 `DeploymentProvider` 协议并在 `ServiceRegistry` 中自动注册。添加新服务只需创建一个新的 Provider 文件。

## 许可证

MIT
