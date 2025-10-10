// autoBackup.js
const cron = require('node-cron');
const { execFile } = require('node:child_process');

const SCRIPT = '/home/ubuntu/Desktop/BOTLIBERAR/commands/db-backup.sh'; // caminho absoluto do teu script
const CHANNEL_ID = '1415848601762136206'; // ID do canal do Discord
const SCHEDULE = '0 */6 * * *'; // corre de 6 em 6 horas

// const SCHEDULE = '0 * * * *'; // corre de hora em hora


let running = false;

async function runOnce(client){
  if (running) return;
  running = true;

  const channel = await client.channels.fetch(CHANNEL_ID).catch(() => null);
  if (channel) await channel.send('A iniciar backup automático...');

  execFile(SCRIPT, { timeout: 15 * 60 * 1000 }, async (err, stdout, stderr) => {
    running = false;
    if (err) {
      console.error('auto-backup erro:', err, stderr);
      if (channel) await channel.send('❌ Backup automático falhou.');
      return;
    }
    const out = (stdout || '').trim();
    if (channel) await channel.send(`✅ Backup automático concluído: \`${out || 'OK'}\``);
  });
}

function startAutoBackup(client){
  cron.schedule(SCHEDULE, () => runOnce(client), { timezone: 'Europe/Lisbon' });

  // Log mais "bonito"
  console.log('⏱️ Auto-backup agendado: de 6 em 6 horas (00:00, 06:00, 12:00, 18:00)');
}

module.exports = { startAutoBackup, runOnce };
