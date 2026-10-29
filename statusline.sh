#!/bin/bash
# Claude Code 状态栏：
# cache 本轮命中率 | avg 会话平均 | ⏱ 缓存过期倒计时 | 5h 额度 | 7d 额度 | ↑上下文 ↓输出 ◆窗口 | $花费

jq -rj '
  def c(code; s): "\u001b[" + code + "m" + s + "\u001b[0m";
  def dim(s): c("2"; s);
  def pct_color(p): if p < 80 then "32" elif p < 90 then "33" else "31" end;
  def hit_color(p): if p >= 80 then "32" elif p >= 50 then "33" else "31" end;
  def pad2(n): (n | tostring) as $s | if ($s | length) < 2 then "0" + $s else $s end;
  def one_dp(x): (x * 10 | round) as $t | (($t / 10 | floor) | tostring) + "." + (($t % 10) | tostring);
  def human(n):
    if n >= 1000000 then one_dp(n / 1000000) + "M"
    elif n >= 1000 then one_dp(n / 1000) + "k"
    else (n | tostring) end;
  def dur(sec):
    if sec <= 0 then "0m"
    elif sec >= 86400 then ((sec / 86400 | floor) | tostring) + "d" + (((sec % 86400) / 3600 | floor) | tostring) + "h"
    elif sec >= 3600 then ((sec / 3600 | floor) | tostring) + "h" + (((sec % 3600) / 60 | floor) | tostring) + "m"
    else ((sec / 60 | floor) | tostring) + "m" end;
  def bar(p):
    ((p / 10) | round | if . > 10 then 10 elif . < 0 then 0 else . end) as $n
    | c(pct_color(p); "▮" * $n // "") + c("90"; "▮" * (10 - $n) // "");
  def limit(name; o):
    if o == null then dim(name + " --")
    else (o.used_percentage // 0) as $p
      | dim(name) + " " + bar($p) + " " + c(pct_color($p); ($p | round | tostring) + "%")
        + " " + dim("↻" + dur((o.resets_at // now) - now | floor))
    end;

  (now | floor) as $now
  | (" " + dim("|") + " ") as $sep

  # 1. 本轮命中率 + 会话平均
  | (.context_window.current_usage // {}) as $u
  | (($u.input_tokens // 0) + ($u.cache_creation_input_tokens // 0) + ($u.cache_read_input_tokens // 0)) as $tot
  | (if $tot > 0 then ($u.cache_read_input_tokens // 0) * 100 / $tot | round else null end) as $hit
  | (.prompt_cache.hit_ratio // null | if . == null then null else . * 100 | round end) as $avg
  | (dim("cache") + " " + (if $hit == null then dim("--") else c(hit_color($hit); ($hit | tostring) + "%") end)
     + " " + dim("avg") + " " + (if $avg == null then dim("--") else dim(($avg | tostring) + "%") end)) as $cache

  # 2. 缓存过期倒计时：Claude Code 计算的 expires_at（读写缓存都会刷新 TTL）
  | .prompt_cache.expires_at as $exp
  | (if $exp == null then dim("⏱ --")
     else ($exp - $now) as $left
       | if $left <= 0 then c("31"; "⏱ cold")
         else c(if $left < 300 then "33" else "1" end;
                "⏱ " + pad2($left / 60 | floor) + ":" + pad2($left % 60)) end
     end) as $timer

  # 3/4. 5 小时与 7 天额度
  | limit("5h"; .rate_limits.five_hour) as $h5
  | limit("7d"; .rate_limits.seven_day) as $d7

  # 5. 上下文大小
  | (.context_window // {}) as $cw
  | (c("31"; "↑" + human($cw.total_input_tokens // 0))
     + " " + c("32"; "↓" + human($cw.total_output_tokens // 0))
     + " " + c("34"; "◆" + human($cw.context_window_size // 0))) as $ctx

  # 6. 会话花费
  | c("1"; "$" + ((.cost.total_cost_usd // 0) * 100 | round / 100
                  | tostring | if test("\\.") then (if test("\\.[0-9]$") then . + "0" else . end) else . + ".00" end)) as $cost

  | [$cache + " " + $timer, $h5, $d7, $ctx, $cost] | join($sep)
'
