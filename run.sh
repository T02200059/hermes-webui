#!/bin/bash
set -a
source /Users/yangtb/.hermes/.env
set +a
exec /Users/yangtb/.hermes/hermes-agent/venv/bin/python /Users/yangtb/projects/ai/hermes-webui/server.py
