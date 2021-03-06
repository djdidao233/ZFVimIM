WORK_DIR=$(cd "$(dirname "$0")"; pwd)
REPO_PATH=$1
GIT_USER_EMAIL=$2
GIT_USER_NAME=$3
GIT_USER_TOKEN=$4
CLEANUP_SCRIPT=$5
CACHE_PATH=$6
if test "1" = "0" \
    || test "x-$REPO_PATH" = "x-" \
    || test "x-$GIT_USER_EMAIL" = "x-" \
    || test "x-$GIT_USER_NAME" = "x-" \
    || test "x-$GIT_USER_TOKEN" = "x-" \
    || test "x-$CLEANUP_SCRIPT" = "x-" \
    || test "x-$CACHE_PATH" = "x-" \
    ; then
    exit 1
fi

rm -rf "$CACHE_PATH" >/dev/null 2>&1
mkdir -p "$CACHE_PATH"
cp -r "$REPO_PATH/.git" "$CACHE_PATH/" >/dev/null 2>&1
sh "$CLEANUP_SCRIPT" "$CACHE_PATH" "$GIT_USER_EMAIL" "$GIT_USER_NAME" "$GIT_USER_TOKEN"
result="$?"
rm -rf "$CACHE_PATH" >/dev/null 2>&1
exit $result

