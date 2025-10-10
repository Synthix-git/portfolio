// commands/clearchat.js
const ALLOWED_ROLES = [
  "888367114065428524", // Dono
  "888367114065428523"  // Developer
];

module.exports = {
  name: 'clearchat',
  description: 'Apaga um número de mensagens da sala',

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

      // Número de mensagens a apagar
      const amount = parseInt(args[0], 10);
      if (isNaN(amount) || amount < 1 || amount > 100) {
        return message.reply('Indica um número entre 1 e 100.');
      }

      // Apaga a própria mensagem do comando + quantidade pedida
      await message.channel.bulkDelete(amount + 1, true);

      // Feedback
      const confirm = await message.channel.send(`✅ Apaguei ${amount} mensagens.`);
      setTimeout(() => confirm.delete().catch(() => {}), 5000);
    } catch (err) {
      console.error('Erro no clearchat:', err);
      message.reply('❌ Ocorreu um erro ao apagar mensagens.');
    }
  }
};
