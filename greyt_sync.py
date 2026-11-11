#!/usr/bin/env python3
"""
greyt_sync.py
Native greytHR OAuth2 + PKCE Attendance Sync Daemon and CLI.
Authenticates with modern greytHR portals using OpenSSL RSA-OAEP SHA-256 password encryption,
retrieves door turnstile biometric swipes from /v3/api/attendance/swipes,
and updates ~/.greythr_status.json for the GreytNotch Dynamic Island widget.
"""

import sys
import os
import json
import time
import argparse
import urllib.request
import urllib.error
import urllib.parse
import http.cookiejar
import hashlib
import base64
import subprocess
from datetime import datetime, timedelta, timezone

CONFIG_PATH = os.path.expanduser("~/.greythr_config.json")
STATUS_PATH = os.path.expanduser("~/.greythr_status.json")
PUBKEY_PATH = os.path.expanduser("~/.greythr_pubkey.pem")

# greytHR UAS RSA Public Key (Standard across greytHR deployments)
DEFAULT_PEM_PUBKEY = """-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAoLf7n9YvJsoinXlx6hNS
qcwLZVKR1VoMgrvYPPyfk0c5OmgUoECdxsSwr7fY58BDnAJL/t4xSWjlP8wccPRH
L6R6wXJhBc4/9S7jows/Bc5TqDOdP7TRwhmmHzgBJLabNuDvS5H77iGNjnoob3AW
s/a1dTG0Ztf2p7TUCG2leHW6UckUTvYhGpO9W7WO1rqBpdPlfN7fhhbkNermzfe0
dJSQdTaztAmLco8QCKhKwvMvMXNfF53sAOOkNGBkF/R7TIHtu9slfVy+gJbBYwAr
vmEyoYitD76f7v73YRlMGJcVj+9aWCSQ0Mpdc39wmiH9z9WQdC9TsVVc0TOcF3Ov
FQIDAQAB
-----END PUBLIC KEY-----
"""

def ensure_pubkey_file():
    if not os.path.exists(PUBKEY_PATH):
        with open(PUBKEY_PATH, "w") as f:
            f.write(DEFAULT_PEM_PUBKEY.strip() + "\n")
    return PUBKEY_PATH

def load_config():
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r") as f:
                return json.load(f)
        except Exception as e:
            print(f"[!] Error reading config from {CONFIG_PATH}: {e}")
    return {}

def save_config(config):
    with open(CONFIG_PATH, "w") as f:
        json.dump(config, f, indent=2)
    os.chmod(CONFIG_PATH, 0o600)
    print(f"[*] Configuration saved to {CONFIG_PATH}")

def save_status(status_data):
    with open(STATUS_PATH, "w") as f:
        json.dump(status_data, f, indent=2)

def encrypt_password_openssl(password):
    pubkey_file = ensure_pubkey_file()
    cmd = [
        "openssl", "pkeyutl", "-encrypt", "-pubin",
        "-inkey", pubkey_file,
        "-pkeyopt", "rsa_padding_mode:oaep",
        "-pkeyopt", "rsa_oaep_md:sha256"
    ]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    enc_bytes, err = p.communicate(input=password.encode("utf-8"))
    if p.returncode != 0:
        raise RuntimeError(f"OpenSSL password encryption failed: {err.decode()}")
    return base64.b64encode(enc_bytes).decode("ascii")

class GreytHROAuthClient:
    def __init__(self, domain, username, password):
        cleaned_domain = domain.strip().replace("https://", "").replace("http://", "").rstrip("/")
        if ".greythr.com" in cleaned_domain:
            self.domain = cleaned_domain.split(".greythr.com")[0]
        else:
            self.domain = cleaned_domain
        self.base_url = f"https://{self.domain}.greythr.com"
        self.username = username.strip()
        self.password = password
        
        self.cookie_jar = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self.cookie_jar),
            urllib.request.HTTPSHandler()
        )
        self.access_token = None

    def login(self):
        print(f"[*] Initiating OAuth authentication with {self.base_url} as {self.username}...")
        
        # 1. Fetch session-config from greytHR
        try:
            cfg_req = urllib.request.Request(f"{self.base_url}/uas/v1/session-config", headers={"User-Agent": "Mozilla/5.0"})
            with self.opener.open(cfg_req, timeout=12) as resp:
                s_cfg = json.loads(resp.read().decode())
        except Exception as e:
            print(f"[-] Failed to fetch session-config: {e}")
            return False

        # 2. Generate PKCE Verifier & Challenge
        verifier = base64.urlsafe_b64encode(os.urandom(32)).rstrip(b'=').decode('ascii')
        digest = hashlib.sha256(verifier.encode('ascii')).digest()
        challenge_pkce = base64.urlsafe_b64encode(digest).rstrip(b'=').decode('ascii')

        # 3. Request Hydra OAuth2 auth URL to obtain login_challenge
        params = {
            "client_id": s_cfg["hydraClient"],
            "redirect_uri": s_cfg["oAuthRedirectUrl"],
            "response_type": "code",
            "scope": "openid offline",
            "state": "greytnotch_state",
            "code_challenge": challenge_pkce,
            "code_challenge_method": "S256",
            "access_id": s_cfg["accessId"]
        }
        auth_url = f"{s_cfg['hydraFrontendServer'].rstrip('/')}/oauth2/auth?{urllib.parse.urlencode(params)}"

        try:
            req_auth = urllib.request.Request(auth_url, headers={"User-Agent": "Mozilla/5.0"})
            with self.opener.open(req_auth, timeout=15) as resp:
                final_url = resp.geturl()
        except Exception as e:
            print(f"[-] Hydra authorization request failed: {e}")
            return False

        parsed_q = urllib.parse.parse_qs(urllib.parse.urlparse(final_url).query)
        login_challenge = parsed_q.get("login_challenge", [None])[0]
        if not login_challenge:
            print("[-] Could not extract login_challenge from Hydra redirect.")
            return False

        # 4. Initiate login call
        init_url = f"{self.base_url}/uas/v1/initiate-login/{login_challenge}"
        req_init = urllib.request.Request(init_url, headers={
            "User-Agent": "Mozilla/5.0",
            "X-OAUTH-CHALLENGE": login_challenge,
            "Accept": "application/json, text/plain, */*"
        })
        try:
            with self.opener.open(req_init, timeout=12) as resp:
                pass
        except Exception as e:
            print(f"[-] Initiate login failed: {e}")
            return False

        # 5. Encrypt password with OpenSSL RSA-OAEP
        try:
            enc_password = encrypt_password_openssl(self.password)
        except Exception as e:
            print(f"[-] Password encryption failed: {e}")
            return False

        # 6. POST /uas/v1/login
        login_url = f"{self.base_url}/uas/v1/login"
        payload = json.dumps({"userName": self.username, "password": enc_password}).encode("utf-8")
        req_login = urllib.request.Request(login_url, data=payload, headers={
            "User-Agent": "Mozilla/5.0",
            "Content-Type": "application/json",
            "X-OAUTH-CHALLENGE": login_challenge,
            "Accept": "application/json, text/plain, */*",
            "Origin": self.base_url,
            "Referer": final_url
        }, method="POST")

        try:
            with self.opener.open(req_login, timeout=15) as resp:
                login_res = json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8", errors="ignore")
            print(f"[-] Login rejected (HTTP {e.code}): {err_body}")
            return False
        except Exception as e:
            print(f"[-] Login request failed: {e}")
            return False

        if login_res.get("loginErrorType") or login_res.get("errorState"):
            print(f"[-] Authentication failed: {login_res.get('message') or login_res.get('loginErrorType')}")
            return False

        redir_url = login_res.get("redirectUrl")
        if not redir_url:
            print("[-] No redirectUrl received from greytHR login response.")
            return False

        # 7. Follow redirectUrl to complete Hydra consent & receive authorization code
        try:
            req_redir = urllib.request.Request(redir_url, headers={"User-Agent": "Mozilla/5.0"})
            with self.opener.open(req_redir, timeout=15) as resp:
                final_cb_url = resp.geturl()
        except Exception as e:
            print(f"[-] Consent redirect failed: {e}")
            return False

        cb_qs = urllib.parse.parse_qs(urllib.parse.urlparse(final_cb_url).query)
        auth_code = cb_qs.get("code", [None])[0]
        if not auth_code:
            print("[-] Authorization code not found in callback.")
            return False

        # 8. Token Request to greytHR backend
        token_req_url = f"{self.base_url}/uas/v1/initiate/token-request"
        req_token = urllib.request.Request(token_req_url, data=b"{}", headers={
            "User-Agent": "Mozilla/5.0",
            "Content-Type": "application/json",
            "CODE": auth_code,
            "PKCE-verifier": verifier,
            "Accept": "application/json, text/plain, */*",
            "Origin": self.base_url
        }, method="POST")

        try:
            with self.opener.open(req_token, timeout=15) as resp:
                pass
        except Exception as e:
            print(f"[-] Token request failed: {e}")
            return False

        # 9. Extract access_token cookie
        for c in self.cookie_jar:
            if c.name == "access_token":
                self.access_token = c.value
                break

        if not self.access_token:
            print("[-] access_token cookie not found after token exchange.")
            return False

        print("[+] greytHR login successful & access token acquired!")
        return True

    def fetch_today_swipes(self):
        if not self.access_token:
            if not self.login():
                return None, "Authentication failed"

        today_str = datetime.now().strftime("%Y-%m-%d")
        print(f"[*] Fetching swipes for {today_str} from {self.base_url}/v3/api/attendance/swipes...")

        headers_api = {
            "User-Agent": "Mozilla/5.0",
            "ACCESS-TOKEN": self.access_token,
            "Accept": "application/json, text/plain, */*",
            "Origin": self.base_url,
            "Referer": f"{self.base_url}/v3/portal"
        }

        url = f"{self.base_url}/v3/api/attendance/swipes?date={today_str}"
        try:
            req = urllib.request.Request(url, headers=headers_api)
            with self.opener.open(req, timeout=15) as resp:
                raw = resp.read().decode("utf-8")
                swipes = json.loads(raw)
                if isinstance(swipes, list):
                    return swipes, None
                elif isinstance(swipes, dict) and "data" in swipes:
                    return swipes["data"], None
                return None, "Unexpected swipe format"
        except Exception as e:
            return None, str(e)

def parse_swipes_and_calculate(swipes, target_hours=8.0):
    if not swipes or len(swipes) == 0:
        return None

    # Parse all punch times
    # In greytHR /v3/api/attendance/swipes, punchTime is in UTC (e.g. "2026-11-06T04:56:07")
    local_times = []
    emp_name = None
    emp_no = None

    for item in swipes:
        if not emp_name and isinstance(item.get("employee"), dict):
            emp_name = item["employee"].get("name")
            emp_no = item["employee"].get("employeeNo")

        punch_str = item.get("punchTime")
        if not punch_str:
            continue

        try:
            # Treat as UTC and convert to local system timezone
            utc_dt = datetime.fromisoformat(punch_str).replace(tzinfo=timezone.utc)
            local_dt = utc_dt.astimezone() # converts to local system timezone (e.g. IST)
            local_times.append(local_dt)
        except Exception:
            continue

    if not local_times:
        return None

    # Sort ascending: earliest swipe of the day is index 0
    local_times.sort()
    first_dt = local_times[0]
    target_dt = first_dt + timedelta(hours=target_hours)

    return {
        "first_dt": first_dt,
        "target_dt": target_dt,
        "total_swipes": len(local_times),
        "emp_name": emp_name,
        "emp_no": emp_no
    }

def sync_attendance(domain, username, password, target_hours=8.0):
    client = GreytHROAuthClient(domain, username, password)
    swipes, err = client.fetch_today_swipes()

    now = datetime.now()
    today_str = now.strftime("%Y-%m-%d")

    if err or swipes is None:
        print(f"[-] Sync failed: {err}")
        return False, err

    parsed = parse_swipes_and_calculate(swipes, target_hours)

    if not parsed:
        print("[-] No swipes recorded yet for today.")
        payload = {
            "status": "WAITING_FOR_SWIPE",
            "message": "Waiting for door turnstile sync...",
            "date": today_str,
            "first_in": None,
            "target_out": None,
            "required_hours": target_hours,
            "last_synced": now.strftime("%I:%M %p"),
            "domain": domain
        }
        save_status(payload)
        return True, "No swipe yet"

    first_dt = parsed["first_dt"]
    target_dt = parsed["target_dt"]

    first_in_fmt = first_dt.strftime("%I:%M %p").lstrip("0")
    target_out_fmt = target_dt.strftime("%I:%M %p").lstrip("0")

    payload = {
        "status": "TRACKING",
        "date": today_str,
        "first_in": first_in_fmt,
        "first_in_iso": first_dt.isoformat(),
        "target_out": target_out_fmt,
        "target_out_iso": target_dt.isoformat(),
        "required_hours": target_hours,
        "last_synced": now.strftime("%I:%M %p"),
        "employee_name": parsed.get("emp_name"),
        "employee_no": parsed.get("emp_no") or username,
        "total_swipes_today": parsed["total_swipes"],
        "domain": domain
    }
    save_status(payload)

    print(f"\n[✓] ATTENDANCE SYNCED SUCCESSFULLY!")
    if parsed.get("emp_name"):
        print(f"    Employee:     {parsed['emp_name']} ({parsed.get('emp_no')})")
    print(f"    First Swipe:  {first_in_fmt}")
    print(f"    Target Exit:  {target_out_fmt} ({target_hours} Hours)")
    print(f"    Total Swipes: {parsed['total_swipes']} recorded today")
    return True, f"First In: {first_in_fmt}"

def main():
    parser = argparse.ArgumentParser(description="greytHR Native Attendance Sync")
    parser.add_argument("--domain", help="greytHR company domain (e.g. acme)")
    parser.add_argument("--username", help="Employee ID / username")
    parser.add_argument("--password", help="greytHR password")
    parser.add_argument("--hours", type=float, default=8.0, help="Required hours (default 8.0)")
    parser.add_argument("--daemon", action="store_true", help="Run continuously in background")
    parser.add_argument("--interval", type=int, default=300, help="Polling interval in seconds")
    parser.add_argument("--manual-in", help="Manually set first-in time (e.g. '09:15 AM') for testing")

    args = parser.parse_args()

    if args.manual_in:
        now = datetime.now()
        first_swipe = args.manual_in
        for fmt in ("%I:%M %p", "%H:%M", "%I:%M%p"):
            try:
                parsed_t = datetime.strptime(first_swipe, fmt).time()
                first_dt = datetime.combine(now.date(), parsed_t)
                break
            except ValueError:
                continue
        else:
            first_dt = now.replace(hour=9, minute=0, second=0)

        target_dt = first_dt + timedelta(hours=args.hours)
        payload = {
            "status": "TRACKING",
            "date": now.strftime("%Y-%m-%d"),
            "first_in": first_dt.strftime("%I:%M %p").lstrip("0"),
            "first_in_iso": first_dt.isoformat(),
            "target_out": target_dt.strftime("%I:%M %p").lstrip("0"),
            "target_out_iso": target_dt.isoformat(),
            "required_hours": args.hours,
            "last_synced": now.strftime("%I:%M %p"),
            "domain": "manual"
        }
        save_status(payload)
        print(f"[✓] Manual status set: First in {payload['first_in']} -> Target out {payload['target_out']}")
        return

    config = load_config()
    domain = args.domain or config.get("domain")
    username = args.username or config.get("username")
    password = args.password or config.get("password")
    hours = args.hours or config.get("hours", 8.0)

    if not domain or not username or not password:
        print("[!] Missing credentials. Please provide them or run configure.")
        domain = input("greytHR Company Domain (e.g. 'acme'): ").strip()
        username = input("Employee ID / Username: ").strip()
        import getpass
        password = getpass.getpass("Password: ").strip()
        save_choice = input("Save credentials to ~/.greythr_config.json? [Y/n]: ").strip().lower()
        if save_choice != "n":
            save_config({"domain": domain, "username": username, "password": password, "hours": hours})

    if args.daemon:
        print(f"[*] Starting background daemon (polling every {args.interval}s)...")
        while True:
            try:
                success, msg = sync_attendance(domain, username, password, target_hours=hours)
                # If we successfully captured the first swipe, poll every 30 minutes
                if success and "First In" in msg:
                    time.sleep(1800)
                else:
                    time.sleep(args.interval)
            except KeyboardInterrupt:
                print("\n[*] Daemon stopped.")
                break
            except Exception as e:
                print(f"[!] Poller error: {e}")
                time.sleep(args.interval)
    else:
        sync_attendance(domain, username, password, target_hours=hours)

if __name__ == "__main__":
    main()
