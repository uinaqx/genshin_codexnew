#!/bin/zsh
set -eu

palette=$'可莉主题官方配色\n基础主题：浅色\n强调色：#C94A3C\n背景色：#FFF9F0\n前景色：#4B2B28\n辅助暖金：#E8B04A\n\n请在 ChatGPT/Codex 的“设置 → 外观”中使用这些颜色。'
printf '%s' "$palette" | pbcopy
open 'codex://settings'
osascript -e 'display notification "配色已复制，请在“设置 → 外观”中填写" with title "可莉 Codex 安全版"'
