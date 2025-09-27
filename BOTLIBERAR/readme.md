# 🤖 BOTLIBERAR

Bot de Discord para administração de servidores **FiveM / vRP (Syn Network)**.  
Automatiza **whitelist** por modal, **backups** de base de dados (manual e automático) e **DM em massa** por cargo.

---

## ✨ Funcionalidades

- 🔓 **Whitelist por Modal** (canal fixo):
  - Bot publica um embed com botão **“Liberar Acesso”**.
  - O utilizador introduz o **ID (passaporte)** no modal.
  - O bot verifica `accounts.id` na DB; se existir:
    - `UPDATE accounts SET whitelist = 1 WHERE id = ?`
    - Atualiza nickname para `Nome | ID` (idempotente: limpa `| N` antigo).
    - Ajusta cargos: remove “Aguardando Liberação” e adiciona “Whitelist Liberado”.
    - Regista **logs** num canal.
- 💾 **Backups da DB**:
  - `!backupdb` executa `db-backup.sh` (mysqldump + gzip + rotação 7 dias).
  - **Auto-backup** de 6 em 6 horas (configurável) com status num canal.
- 📩 **DM por Cargo**: `!dmrole <@cargo|roleId> <mensagem>` (delay para evitar rate limit).
- 🧹 **Clear chat**: `!clearchat <1..100>` (apaga em massa).

---

## 🗂️ Estrutura

server.js # bootstrap do bot
autoBackup.js # agendamento e execução do backup automático
components/liberar.js # fluxo de whitelist por modal + cargos + logs
commands/backupdb.js # comando !backupdb (chama db-backup.sh)
commands/db-backup.sh # script bash de backup (mysqldump)
commands/dmrole.js # comando !dmrole
commands/clearchat.js # comando !clearchat
config.json # configurações do bot e MySQL
fxmanifest.lua # opcional: rodar como resource no FiveM

yaml
Copy code

---

## ⚙️ Requisitos

- **Linux** (Ubuntu/Debian)
- **Node.js ≥ 18** (recomendado)
- **MySQL** com `mysqldump`
- Permissões no Discord:
  - *Server Members Intent*, *Message Content Intent* (ativar no Developer Portal)
  - **Manage Nicknames**, **Manage Roles**, **Read/Send Messages**, **Read Message History**

---

## 📦 Instalação (Linux)

```bash
sudo apt update
sudo apt install -y nodejs npm mysql-client
git clone https://github.com/teuuser/BOTLIBERAR.git
cd BOTLIBERAR
npm install
Configuração (config.json)
Exemplo (já incluído no projeto):

json
Copy code
{
  "token": "DISCORDTOKEN",
  "channelLiberarId": "DISCORDCHANNEL",
  "mysql": {
    "host": "localhost",
    "user": "root",
    "password": "",
    "database": "NOMEDB"
  }
}
Em components/liberar.js:

Substitui logChannelId pelo ID do canal de logs.

Ajusta os IDs dos cargos:

cargoRemoverId = “Aguardando Liberação”

cargoAdicionarId = “Whitelist Liberado”

Script de backup (commands/db-backup.sh)
Edita as variáveis no topo:

bash
Copy code
DB="NOMEDB"
USER="root"
PASS=""
HOST="127.0.0.1"
OUT_DIR="/home/ubuntu/backups/BOTLIBERAR"
E garante o caminho correto em:

commands/backupdb.js → SCRIPT="/caminho/para/BOTLIBERAR/commands/db-backup.sh"

autoBackup.js → SCRIPT="/caminho/para/BOTLIBERAR/commands/db-backup.sh"

bash
Copy code
chmod +x commands/db-backup.sh
Iniciar
bash
Copy code
node server.js
(Opcional) PM2
bash
Copy code
npm i -g pm2
pm2 start server.js --name "BOTLIBERAR"
pm2 save
pm2 startup
🧪 Uso
Whitelist: no canal configurado (channelLiberarId), clicar “Liberar Acesso” e inserir o ID.

Backup manual: !backupdb (cooldown 5 min; requer cargo autorizado).

DM por cargo: !dmrole @Cargo Mensagem...

Limpar chat: !clearchat 50

🗄️ Base de dados (expectativa)
Tabela: accounts

id (INT) — passaporte

whitelist (TINYINT/BOOL) — 0/1

Adapta os nomes caso a tua estrutura seja diferente.

🔒 Boas práticas
Usa um utilizador MySQL restrito ao schema necessário.

Mantém o token fora do git (usa ficheiro local ou secrets do CI/CD).

Revê permissões de cargos do bot (para alterar nickname/roles).

Ajusta o cron em autoBackup.js (SCHEDULE) e o fuso (Europe/Lisbon).

👤 Autor
Feito com 💻 por Synthix