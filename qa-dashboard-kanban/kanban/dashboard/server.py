#!/usr/bin/env python3
"""
server.py - Simple HTTP server for Kanban QA Dashboard
"""

import os
import json
import http.server
import socketserver
from pathlib import Path
from urllib.parse import urlparse, parse_qs

# Configuration
PORT = 8081
SCRIPT_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent
DATA_DIR = PROJECT_DIR / "data"
CONFIG_DIR = PROJECT_DIR / "config"
KANBAN_FILE = DATA_DIR / "kanban.json"
TOKEN_FILE = DATA_DIR / "token-usage.json"
CONFIG_FILE = CONFIG_DIR / "agents-config.json"
AUDIT_STATS_FILE = PROJECT_DIR.parent / "qa" / "audit-stats.json"

class KanbanRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.send_header("Cache-Control", "no-cache, no-store, must-revalidate, max-age=0")
            self.send_header("Pragma", "no-cache")
            self.send_header("Expires", "0")
            self.end_headers()
            with open(SCRIPT_DIR / "index.html", "rb") as f:
                self.wfile.write(f.read())
                
        elif self.path == "/api/kanban":
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            
            if KANBAN_FILE.exists():
                with open(KANBAN_FILE, "r") as f:
                    self.wfile.write(f.read().encode())
            else:
                self.wfile.write(b'{"tasks": [], "lastUpdate": null}')
                
        elif self.path == "/api/tokens":
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            
            if TOKEN_FILE.exists():
                with open(TOKEN_FILE, "r") as f:
                    self.wfile.write(f.read().encode())
            else:
                self.wfile.write(b'{"weeklyUsed": 0}')
                
        elif self.path == "/api/config":
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            
            if CONFIG_FILE.exists():
                with open(CONFIG_FILE, "r") as f:
                    self.wfile.write(f.read().encode())
            else:
                default_config = {
                    "tokenBudget": {
                        "weeklyLimit": 50000,
                        "warningThreshold": 0.8,
                        "criticalThreshold": 0.95
                    }
                }
                self.wfile.write(json.dumps(default_config).encode())
                
        elif self.path == "/api/audit-stats":
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            
            if AUDIT_STATS_FILE.exists():
                with open(AUDIT_STATS_FILE, "r") as f:
                    self.wfile.write(f.read().encode())
            else:
                default_stats = {
                    "current_stats": {
                        "error_rate": 0,
                        "total_logs_scanned": 0,
                        "logs_with_errors": 0
                    }
                }
                self.wfile.write(json.dumps(default_stats).encode())
        else:
            self.send_error(404, "Not Found")
    
    def do_POST(self):
        if self.path == "/api/config":
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            try:
                updates = json.loads(post_data.decode('utf-8'))
                
                # Load existing config
                if CONFIG_FILE.exists():
                    with open(CONFIG_FILE, "r") as f:
                        config = json.load(f)
                else:
                    config = {
                        "tokenBudget": {},
                        "agents": {}
                    }
                
                # Update tokenBudget
                if "tokenBudget" not in config:
                    config["tokenBudget"] = {}
                
                config["tokenBudget"]["weeklyLimit"] = updates.get("weeklyLimit", 50000)
                config["tokenBudget"]["warningThreshold"] = updates.get("warningThreshold", 0.8)
                config["tokenBudget"]["criticalThreshold"] = updates.get("criticalThreshold", 0.95)
                
                # Save config
                CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
                with open(CONFIG_FILE, "w") as f:
                    json.dump(config, f, indent=2)
                
                self.send_response(200)
                self.send_header("Content-type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(json.dumps({"success": True}).encode())
                
            except Exception as e:
                self.send_error(500, f"Failed to save config: {str(e)}")
        else:
            self.send_error(404, "Not Found")
    
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
    
    def log_message(self, format, *args):
        # Suppress request logging
        pass

def kill_existing_server():
    """Kill any process using the port"""
    import subprocess
    try:
        result = subprocess.run(
            ["lsof", "-ti", f":{PORT}"],
            capture_output=True,
            text=True
        )
        if result.stdout.strip():
            pids = result.stdout.strip().split('\n')
            for pid in pids:
                if pid.strip():
                    print(f"🔄 Killing existing server on port {PORT} (PID: {pid})")
                    subprocess.run(["kill", "-9", pid])
            import time
            time.sleep(2)  # Longer wait for proper cleanup
    except Exception as e:
        print(f"Warning during cleanup: {e}")
        pass

def main():
    # Kill existing server
    kill_existing_server()
    
    # Change to dashboard directory
    os.chdir(SCRIPT_DIR)
    
    # Start server
    with socketserver.TCPServer(("", PORT), KanbanRequestHandler) as httpd:
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print(f"🚀 Kanban QA Dashboard running on http://localhost:{PORT}")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("")
        print("📊 Dashboard ready!")
        print("Press Ctrl+C to stop")
        print("")
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n🛑 Server stopped")

if __name__ == "__main__":
    main()
