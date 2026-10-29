# claude-code-statusline

A compact [Claude Code](https://code.claude.com) status line that shows prompt-cache health, subscription rate limits, context size and session cost on one row.

一个 Claude Code 状态栏脚本，一行显示缓存命中率、缓存过期倒计时、5 小时 / 7 天额度、上下文大小和本次会话花费。

```
cache 99% avg 94% ⏱ 47:36 | 5h ▮▮▮▮▮▮▮▮▮▮ 2% ↻4h36m | 7d ▮▮▮▮▮▮▮▮▮▮ 76% ↻13h56m | ↑68.6k ↓9.6k ◆1.0M | $206.51
```

## 显示内容

| 段 | 含义 | 数据来源（状态栏 stdin JSON） |
|---|---|---|
| `cache 99%` | 最近一次 API 请求的缓存命中率：读缓存 ÷（未缓存输入 + 写缓存 + 读缓存） | `context_window.current_usage` |
| `avg 94%` | 本次会话按 token 加权的平均命中率（仅主会话，不含子代理） | `prompt_cache.hit_ratio` |
| `⏱ 47:36` | 缓存过期倒计时，剩不到 5 分钟变黄，过期显示 `cold` | `prompt_cache.expires_at` |
| `5h` / `7d` | 订阅额度已用百分比 + 距离重置的时间 | `rate_limits.five_hour` / `rate_limits.seven_day` |
| `↑ ↓ ◆` | 当前上下文输入 token（含缓存）、输出 token、上下文窗口大小 | `context_window` |
| `$` | 本次会话估算花费（按标价，可能与实际账单不同） | `cost.total_cost_usd` |

缺少的字段显示为 `--`，不会报错。

## 依赖

- Claude Code v2.1.251 或更高（`prompt_cache` 字段从这个版本开始提供）
- [`jq`](https://jqlang.org)
- `5h` / `7d` 额度只对 claude.ai Pro / Max 订阅用户提供；API key 用户这两段会显示 `--`

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/MuQY1818/claude-code-statusline/main/statusline.sh -o ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

然后在 `~/.claude/settings.json` 的最外层加入：

```json
"statusLine": {
  "type": "command",
  "command": "~/.claude/statusline.sh",
  "padding": 0,
  "refreshInterval": 1
}
```

`refreshInterval: 1` 让倒计时每秒刷新；不加的话只在新回复到达时刷新。

也可以用 `jq` 直接写入，不影响其他配置：

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.bak
jq '.statusLine = {"type":"command","command":"~/.claude/statusline.sh","padding":0,"refreshInterval":1}' \
  ~/.claude/settings.json.bak > ~/.claude/settings.json
```

保存后 Claude Code 会自动刷新状态栏，无需重启。

## 自定义

- 颜色阈值：修改脚本里的 `pct_color`（额度）和 `hit_color`（命中率）
- 进度条字符：修改 `bar` 里的 `▮`

## License

MIT
