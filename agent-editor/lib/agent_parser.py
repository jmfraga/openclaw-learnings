#!/usr/bin/env python3
"""
agent_parser.py - Parse agent sessions and extract status/usage info
Configuration: Set OPENCLAW_DIR environment variable to point to your OpenClaw root.
Default: ~/.openclaw
"""

import json
import time
import os
from pathlib import Path
from datetime import datetime

# Configuration: Use OPENCLAW_DIR env var, default to ~/.openclaw
OPENCLAW_DIR = Path(os.getenv('OPENCLAW_DIR', str(Path.home() / '.openclaw')))
AGENTS_BASE = OPENCLAW_DIR / 'agents'
CONFIG_PATH = OPENCLAW_DIR / 'openclaw.json'

# Cache with 30s TTL
_cache = {
    'data': None,
    'timestamp': 0,
    'ttl': 30
}

def get_agent_list():
    """Read agent list from openclaw.json"""
    try:
        with open(CONFIG_PATH, 'r') as f:
            config = json.load(f)
        
        agents = config.get('agents', {}).get('list', [])
        default_model = config.get('agents', {}).get('defaults', {}).get('model', {}).get('primary')
        
        result = []
        for agent in agents:
            # Extract model
            model = agent.get('model')
            if isinstance(model, dict):
                model_str = model.get('primary')
            elif isinstance(model, str):
                model_str = model
            else:
                model_str = default_model
            
            # Strip provider prefix (anthropic/claude-x → claude-x)
            if model_str and '/' in model_str:
                model_str = model_str.split('/', 1)[1]
            
            result.append({
                'id': agent.get('id'),
                'model': model_str
            })
        
        return result
    except Exception as e:
        print(f"Error reading agent list: {e}")
        return []

def get_latest_session_file(agent_name):
    """Get the most recent session file for an agent"""
    sessions_dir = AGENTS_BASE / agent_name / 'sessions'
    
    if not sessions_dir.exists():
        return None
    
    try:
        # Include both active .jsonl and recently deleted ones
        all_files = list(sessions_dir.glob('*.jsonl')) + list(sessions_dir.glob('*.jsonl.deleted.*'))
        
        if not all_files:
            return None
        
        # Sort by modification time, most recent first
        all_files.sort(key=lambda f: f.stat().st_mtime, reverse=True)
        
        latest = all_files[0]
        return {
            'file': latest.name,
            'path': latest,
            'mtime': datetime.fromtimestamp(latest.stat().st_mtime),
            'deleted': '.deleted.' in latest.name
        }
    except Exception as e:
        print(f"Error finding session file for {agent_name}: {e}")
        return None

def parse_agent_session(agent_name, config_model):
    """Parse an agent's session file to extract status and usage"""
    latest_file = get_latest_session_file(agent_name)
    
    if not latest_file:
        return {
            'name': agent_name,
            'status': 'offline',
            'lastActivity': None,
            'model': config_model,
            'usage': None
        }
    
    try:
        with open(latest_file['path'], 'r') as f:
            lines = f.read().strip().split('\n')
        
        last_message = None
        last_model = None
        
        # Parse from end to find most recent message
        for line in reversed(lines):
            try:
                data = json.loads(line)
                if data.get('type') == 'message':
                    if not last_message:
                        last_message = data
                    if data.get('message', {}).get('model'):
                        last_model = data['message']['model']
                        break
            except:
                continue
        
        if not last_message:
            return {
                'name': agent_name,
                'status': 'offline',
                'lastActivity': int(latest_file['mtime'].timestamp() * 1000),
                'model': config_model,
                'usage': None
            }
        
        # Extract timestamp
        timestamp_raw = last_message.get('timestamp') or last_message.get('message', {}).get('timestamp')
        
        if timestamp_raw:
            try:
                if isinstance(timestamp_raw, (int, float)):
                    timestamp = int(timestamp_raw)
                else:
                    timestamp = int(datetime.fromisoformat(timestamp_raw.replace('Z', '+00:00')).timestamp() * 1000)
            except:
                timestamp = int(latest_file['mtime'].timestamp() * 1000)
        else:
            timestamp = int(latest_file['mtime'].timestamp() * 1000)
        
        # Determine status
        now = time.time() * 1000  # milliseconds
        age_minutes = (now - timestamp) / 60000
        
        if age_minutes < 5:
            status = 'active'
        elif age_minutes < 60:
            status = 'idle'
        else:
            status = 'offline'
        
        return {
            'name': agent_name,
            'status': status,
            'lastActivity': timestamp,
            'model': config_model,
            'usage': last_message.get('message', {}).get('usage'),
            'sessionFile': latest_file['file'],
            'fileModified': int(latest_file['mtime'].timestamp() * 1000)
        }
        
    except Exception as e:
        print(f"Error parsing session for {agent_name}: {e}")
        return {
            'name': agent_name,
            'status': 'error',
            'lastActivity': None,
            'model': config_model,
            'usage': None,
            'error': str(e)
        }

def get_agents_info():
    """Get info for all agents"""
    now = time.time()
    
    # Return cached data if still valid
    if _cache['data'] and (now - _cache['timestamp']) < _cache['ttl']:
        return _cache['data']
    
    try:
        agent_configs = get_agent_list()
        agents = [parse_agent_session(a['id'], a['model']) for a in agent_configs]
        
        # Update cache
        _cache['data'] = agents
        _cache['timestamp'] = now
        
        return agents
    except Exception as e:
        print(f"Error fetching agents info: {e}")
        return []

def get_all_session_messages():
    """Get all messages from all agent sessions"""
    agent_configs = get_agent_list()
    all_messages = []
    
    for agent_config in agent_configs:
        sessions_dir = AGENTS_BASE / agent_config['id'] / 'sessions'
        
        if not sessions_dir.exists():
            continue
        
        try:
            jsonl_files = list(sessions_dir.glob('*.jsonl'))
            
            for file_path in jsonl_files:
                try:
                    with open(file_path, 'r') as f:
                        lines = f.read().strip().split('\n')
                    
                    for line in lines:
                        try:
                            data = json.loads(line)
                            if data.get('type') == 'message':
                                timestamp_raw = data.get('timestamp') or data.get('message', {}).get('timestamp')
                                
                                if timestamp_raw:
                                    try:
                                        if isinstance(timestamp_raw, (int, float)):
                                            timestamp = int(timestamp_raw)
                                        else:
                                            timestamp = int(datetime.fromisoformat(timestamp_raw.replace('Z', '+00:00')).timestamp() * 1000)
                                    except:
                                        timestamp = None
                                else:
                                    timestamp = None
                                
                                all_messages.append({
                                    'agent': agent_config['id'],
                                    'timestamp': timestamp,
                                    'type': data.get('type'),
                                    'model': data.get('message', {}).get('model'),
                                    'usage': data.get('message', {}).get('usage'),
                                    'data': data
                                })
                        except:
                            continue
                except:
                    continue
        except:
            continue
    
    return all_messages
