from collections import defaultdict, deque
import time

from flask import Flask, jsonify, request

app = Flask(__name__)

DEMO_USER = "student"
DEMO_PASS = "CorrectHorseBatteryStaple"

# Per-user failure history and temporary lockouts for safe, visible demo behavior.
fail_times = defaultdict(lambda: deque(maxlen=20))
locked_until = defaultdict(float)


@app.get("/")
def index():
    return jsonify({
        "service": "auth-demo",
        "message": "Use POST /login with JSON {username, password}",
    })


@app.post("/login")
def login():
    body = request.get_json(silent=True) or {}
    username = str(body.get("username", ""))
    password = str(body.get("password", ""))

    now = time.time()

    if now < locked_until[username]:
        return jsonify({"ok": False, "msg": "Locked. Try again later."}), 429

    q = fail_times[username]
    while q and now - q[0] > 60:
        q.popleft()

    ok = username == DEMO_USER and password == DEMO_PASS

    print(
        f"[{time.strftime('%H:%M:%S')}] login attempt user={username!r} ok={ok}",
        flush=True,
    )

    if ok:
        return jsonify({"ok": True, "msg": "Welcome (demo)."}), 200

    q.append(now)
    if len(q) >= 5:
        locked_until[username] = now + 30
        return jsonify({"ok": False, "msg": "Too many attempts. Locked for 30s."}), 429

    return jsonify({"ok": False, "msg": "Invalid credentials."}), 401


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
