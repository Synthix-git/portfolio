// commands/backupdb.js
const { execFile } = require('node:child_process');

const SCRIPT = '/home/ubuntu/Desktop/BOTLIBERAR/commands/db-backup.sh'; // caminho absoluto
const COOLDOWN_MS = 5 * 60 * 1000; // 5 minutos
let lastRun = 0;

// Lista de roles que podem usar o comando
const ALLOWED_ROLES = [
  "888367114065428524", // Dono
  "888367114065428523"  // Developer
  // adiciona mais se precisares
];

module.exports = {
  name: 'backupdb',
  description: 'Faz backup da base de dados (mysqldump + gzip)',

  /**
   * @param {import('discord.js').Client} client
   * @param {import('discord.js').Message} message
   * @param {string[]} args
   */
  async execute(client, message, args) {
    try {
      // Verificação por cargos
      const hasRole = ALLOWED_ROLES.some(roleId => message.member.roles.cache.has(roleId));
      if (!hasRole) {
        return message.reply('Sem permissão.');
      }

      // Cooldown global
      const now = Date.now();
      const left = lastRun + COOLDOWN_MS - now;
      if (left > 0) {
        const mins = Math.ceil(left / 60000);
        return message.reply(`Aguarda ${mins} min antes de novo backup.`);
      }

      // Feedback imediato
      const msg = await message.reply('A criar backup...');

      // Executa o script (.sh tem de ter chmod +x)
      execFile(SCRIPT, { timeout: 15 * 60 * 1000 }, (err, stdout, stderr) => {
        if (err) {
          console.error('backupdb erro:', err, stderr);
          return msg.edit('❌ Falhou ao criar backup.');
        }
        lastRun = now;
        const out = (stdout || '').trim();
        msg.edit(`✅ Backup concluído: \`${out || 'OK'}\``);
      });
    } catch (e) {
      console.error(e);
      message.reply('❌ Erro inesperado ao executar o backup.');
    }
  }
};
