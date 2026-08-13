#!/usr/bin/env bash
# Lint toàn bộ tệp .typ trong docs/typst bằng `tinymist lint`.
#
#   ./scripts/lint-typst.sh                  # lint hết
#   ./scripts/lint-typst.sh typst/common/*.typ   # lint vài tệp chỉ định
#   VERBOSE=1 ./scripts/lint-typst.sh        # giữ nguyên log nội bộ của tinymist
#
# Thoát 0 nếu sạch, 1 nếu có tệp bị báo lỗi.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TYPST_ROOT="$REPO_ROOT/typst"
FONT_PATH="$TYPST_ROOT/common/fonts"

if ! command -v tinymist >/dev/null 2>&1; then
  echo "Không tìm thấy tinymist. Cài bằng một trong các cách sau:" >&2
  echo "  sudo pacman -S tinymist            # Arch" >&2
  echo "  cargo install --locked tinymist    # mọi hệ" >&2
  exit 127
fi

# Danh sách tệp: hoặc lấy từ tham số, hoặc quét typst/ (bỏ tmp/ và out/).
files=()
if [[ $# -gt 0 ]]; then
  files=("$@")
else
  while IFS= read -r f; do
    files+=("$f")
  done < <(find "$TYPST_ROOT" -name '*.typ' \
    -not -path "$TYPST_ROOT/tmp/*" \
    -not -path "$TYPST_ROOT/out/*" | sort)
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "Không có tệp .typ nào để lint."
  exit 0
fi

# Màu chỉ bật khi in ra terminal.
if [[ -t 1 ]]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; DIM=$'\033[2m'; BOLD=$'\033[1m'; OFF=$'\033[0m'
else
  RED=''; GREEN=''; DIM=''; BOLD=''; OFF=''
fi

# tinymist in cả log nội bộ lẫn chẩn đoán ra stderr. Log nội bộ có dạng
# "[2026-08-14T… WARN  tinymist_query::…]" và không liên quan tới nội dung
# báo cáo (chủ yếu là fletcher import cetz), nên lọc bỏ trừ khi VERBOSE=1.
filter_noise() {
  if [[ "${VERBOSE:-0}" == "1" ]]; then
    cat
  else
    grep -v -E '^\[[0-9]{4}-[0-9]{2}-[0-9]{2}T[^]]*(WARN|INFO|DEBUG|TRACE)[^]]*\]'
  fi
}

failed=()
checked=0

for f in "${files[@]}"; do
  if [[ ! -f $f ]]; then
    echo "${RED}bỏ qua${OFF} $f (không tồn tại)" >&2
    failed+=("$f")
    continue
  fi

  # tinymist chạy với cwd = typst/ nên đường dẫn phải tuyệt đối.
  abs="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"

  out=$(cd "$TYPST_ROOT" && tinymist lint \
    --root . \
    --font-path "$FONT_PATH" \
    --diagnostic-format short \
    "$abs" 2>&1)
  status=$?
  out=$(printf '%s\n' "$out" | filter_noise)

  rel="${abs#"$REPO_ROOT"/}"
  checked=$((checked + 1))

  if [[ $status -eq 0 && -z ${out//[[:space:]]/} ]]; then
    echo "${GREEN}✓${OFF} ${DIM}${rel}${OFF}"
  else
    echo "${RED}✗${OFF} ${BOLD}${rel}${OFF}"
    [[ -n ${out//[[:space:]]/} ]] && printf '%s\n' "$out" | sed 's/^/    /'
    failed+=("$rel")
  fi
done

echo
if [[ ${#failed[@]} -eq 0 ]]; then
  echo "${GREEN}Sạch${OFF} — đã lint $checked tệp."
  exit 0
fi

echo "${RED}${#failed[@]}/${checked} tệp có vấn đề:${OFF}"
printf '  %s\n' "${failed[@]}"
exit 1
