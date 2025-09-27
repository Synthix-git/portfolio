#!/bin/bash

# Caminho absoluto da pasta do bot
BOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Entrar na pasta
cd "$BOT_DIR"

# Verificar se node_modules existe
if [ ! -d "node_modules" ]; then
  echo "🔧 Instalando dependências..."
  npm install
fi

# Iniciar o bot
echo "🚀 Iniciando o bot Discord..."
node server.js
