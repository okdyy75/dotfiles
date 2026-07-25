# ask - ローカルLLM(Ollama)に日本語で質問して macOS 向けシェルコマンドを提案してもらう関数
# .zshrc から `source ~/.ask.sh` して使う（~/bin や PATH 設定は不要）
# 参考: https://zenn.dev/gys/articles/fable5-local-llm-ask-cli

ask() {
  # 関数本体はサブシェル()内で実行し、set / exit を対話シェルに漏らさない
  (
    set -uo pipefail

    VERSION="0.1.0"

    # --- 設定（環境変数で上書き可能） ---
    ASK_HOST="${ASK_HOST:-http://localhost:11434}"
    ASK_MODEL="${ASK_MODEL:-qwen2.5-coder:7b}"
    ASK_THINK_MODEL="${ASK_THINK_MODEL:-gpt-oss:20b}"

    usage() {
      cat <<EOF
ask - ローカルLLM(Ollama)に日本語で質問してシェルコマンドを提案してもらう

使い方:
  ask [オプション] "自然言語の質問"

オプション:
  -m, --model <name>   このコマンドに限りモデルを一時上書き
      --think          推論モードで丁寧に回答（-m 未指定なら ${ASK_THINK_MODEL} へ自動格上げ・遅い）
  -q, --quiet          末尾の注意書きを出さない
  -h, --help           このヘルプを表示
      --version        バージョン表示

環境変数:
  ASK_MODEL         既定モデル (現在: ${ASK_MODEL})
  ASK_THINK_MODEL   --think 時のモデル (現在: ${ASK_THINK_MODEL})
  ASK_HOST          Ollama API の URL (現在: ${ASK_HOST})

例:
  ask "7日以内に更新されたファイルを探したい"
  ask -m gpt-oss:20b "特定モデルを指定して質問"
  ask --think "複雑なパイプが必要な質問"
EOF
    }

    # --- 引数パース ---
    MODEL="$ASK_MODEL"
    MODEL_EXPLICIT=false
    THINK=false
    QUIET=false
    QUESTION=""

    while [ $# -gt 0 ]; do
      case "$1" in
        -m|--model) MODEL="${2:?--model にはモデル名が必要です}"; MODEL_EXPLICIT=true; shift 2;;
        --think)    THINK=true; shift;;
        -q|--quiet) QUIET=true; shift;;
        -h|--help)  usage; exit 0;;
        --version)  echo "ask $VERSION"; exit 0;;
        --)         shift; QUESTION="${QUESTION:+$QUESTION }$*"; break;;
        -*)         echo "不明なオプション: $1" >&2; usage >&2; exit 1;;
        *)          QUESTION="${QUESTION:+$QUESTION }$1"; shift;;
      esac
    done

    if [ -z "${QUESTION// /}" ]; then
      echo "質問を指定してください。" >&2
      echo '例: ask "7日以内に更新されたファイルを探したい"' >&2
      exit 1
    fi

    # --- 依存チェック ---
    command -v curl >/dev/null 2>&1 || { echo "curl が必要です" >&2; exit 1; }
    command -v jq   >/dev/null 2>&1 || { echo "jq が必要です (brew install jq)" >&2; exit 1; }

    # --- Ollama サーバ起動確認（ローカルかつ未起動なら自動起動を試みる） ---
    if ! curl -s -m 2 "$ASK_HOST/api/tags" >/dev/null 2>&1; then
      if command -v ollama >/dev/null 2>&1 && [ "$ASK_HOST" = "http://localhost:11434" ]; then
        echo "Ollama サーバを起動中..." >&2
        (ollama serve >/dev/null 2>&1 &)
        for _ in $(seq 1 20); do
          sleep 0.5
          curl -s -m 2 "$ASK_HOST/api/tags" >/dev/null 2>&1 && break
        done
      fi
      if ! curl -s -m 2 "$ASK_HOST/api/tags" >/dev/null 2>&1; then
        echo "Ollama サーバに接続できません ($ASK_HOST)。'ollama serve' を実行してください。" >&2
        exit 1
      fi
    fi

    # --- think 指定時、-m 未指定なら推論対応モデルへ格上げ ---
    # 既定の qwen2.5-coder 系は think 非対応のため、--think では gpt-oss:20b 等に切替える
    if [ "$THINK" = true ] && [ "$MODEL_EXPLICIT" = false ]; then
      MODEL="$ASK_THINK_MODEL"
    fi

    # --- システムプロンプト ---
    SYSTEM_PROMPT=$(cat <<'PROMPT'
あなたは macOS(zsh/bash) のシェルに精通したアシスタントです。
ユーザーの日本語の質問に対し、最適なシェルコマンドを1つ提案してください。

ルール:
- 環境は必ず macOS。BSD版コマンド(find/sed/stat/date/xargs 等)前提。GNU固有オプション(sed -i の引数省略, date -d, ps --sort, xargs -r 等)は使わない。
- 1行目に実行コマンドを書く。必要なら2〜3行で短く補足。冗長な説明・コードフェンス(```)・挨拶は書かない。
- 実在するコマンドとオプションのみ。不確かなら「要確認」と明記する。
- lsof や ps の出力をパイプで加工する時はヘッダ行(COMMAND/PID 等)に注意。PIDだけ欲しい時は awk ではなく lsof -t や pgrep を使う。
- 破壊的な操作(rm -rf, kill -9, dd 等)は必要な時のみ提案し、一言警告を添える。

参考例（macOSで正しい書き方。丸暗記せず質問に合わせて応用する）:
Q: ポート3000を使っているプロセスをkillしたい
A: lsof -ti :3000 | xargs kill
（lsof -ti はPIDのみ出力。強制終了が必要なら kill の代わりに kill -9）

Q: 3日前の日付をYYYY-MM-DDで表示したい
A: date -v-3d +%F

Q: file.txt の各行末尾の空白を削除して上書き保存したい
A: sed -i '' -E 's/[[:space:]]+$//' file.txt

Q: CPU使用率が高い順にプロセス上位10件を見たい
A: ps -Ao pid,comm,%cpu | sort -k3 -nr | head -n 10
PROMPT
)

    # --- リクエスト組み立て（chat 非対応モデルもあるため /api/generate を使用） ---
    REQ=$(jq -n \
      --arg model "$MODEL" \
      --arg sys "$SYSTEM_PROMPT" \
      --arg q "$QUESTION" \
      '{
         model: $model,
         system: $sys,
         prompt: $q,
         stream: false,
         options: { temperature: 0.2 }
       }')

    # think は対応モデルでのみ有効。既定パスでは付けない（非対応モデルのエラー回避）
    if [ "$THINK" = true ]; then
      REQ=$(printf '%s' "$REQ" | jq '. + {think: true}')
    fi

    # --- 問い合わせ ---
    RESP=$(curl -s -m 180 "$ASK_HOST/api/generate" -d "$REQ")

    # --- エラーハンドリング ---
    ERR=$(printf '%s' "$RESP" | jq -r '.error // empty' 2>/dev/null)
    if [ -n "$ERR" ]; then
      echo "Ollama エラー: $ERR" >&2
      exit 1
    fi

    CONTENT=$(printf '%s' "$RESP" | jq -r '.response // empty' 2>/dev/null)
    if [ -z "$CONTENT" ]; then
      echo "応答を取得できませんでした。" >&2
      printf '%s\n' "$RESP" >&2
      exit 1
    fi

    # --- 出力（モデルが付けがちなコードフェンス行は除去してコピペしやすくする） ---
    CONTENT=$(printf '%s\n' "$CONTENT" | sed -E '/^[[:space:]]*```/d')
    printf '%s\n' "$CONTENT"
    if [ "$QUIET" = false ]; then
      printf '\n⚠ local LLM(%s): 実行前に --help 等で裏取り推奨\n' "$MODEL"
    fi
  )
}
