// commands/dmrole.js
// Envia DM para todos os membros que tenham um cargo específico.
// Uso: !dmrole @Cargo mensagem aqui
//     ou: !dmrole 123456789012345678 mensagem aqui
//
// Requisitos: discord.js v14, Node 18+

const { EmbedBuilder } = require("discord.js");

// === Config local do comando (podes mover para o teu config externo se quiseres) ===
const ALLOWED_ROLES = [
  "888367114065428524", // Dono
  "888367114065428523"  // Developer
];

const DM_DELAY_MS = 800;        // delay entre DMs para evitar rate limit
const COOLDOWN_MS = 60 * 1000;  // cooldown global do comando (1 min)
let lastRun = 0;
// ================================================================================

module.exports = {
  name: "dmrole",
  description: "Envia DM para todos os membros de um cargo. Uso: !dmrole @Cargo mensagem",

  /**
   * @param {import('discord.js').Client} client
   * @param {import('discord.js').Message} message
   * @param {string[]} args
   */
  async execute(client, message, args) {
    try {
      // 1) Verificação de permissão por cargos
      const hasRole = ALLOWED_ROLES.some((roleId) =>
        message.member.roles.cache.has(roleId)
      );
      if (!hasRole) {
        return message.reply("❌ Sem permissão para usar este comando.");
      }

      // 2) Cooldown global simples
      const now = Date.now();
      const left = lastRun + COOLDOWN_MS - now;
      if (left > 0) {
        const secs = Math.ceil(left / 1000);
        return message.reply(`⏳ Aguarda ${secs}s antes de usar novamente.`);
      }

      if (!args.length) {
        return message.reply(
          "Uso: **!dmrole @Cargo mensagem** (ou **!dmrole <roleId> mensagem**)"
        );
      }

      // 3) Resolver o cargo (menção ou ID)
      let role =
        message.mentions.roles.first() ||
        message.guild.roles.cache.get(args[0]);

      if (!role) {
        return message.reply("⚠️ Cargo inválido. Menciona um cargo ou coloca o ID correto.");
      }

      // 4) Mensagem a enviar
      const msgText = args.slice(1).join(" ").trim();
      if (!msgText) {
        return message.reply("⚠️ Escreve a mensagem a enviar por DM após o cargo.");
      }

      // 5) Garantir que temos a lista de membros do cargo
      // (se a cache estiver vazia, faz fetch a todos os membros do servidor)
      if (!role.members || role.members.size === 0) {
        try {
          await message.guild.members.fetch();
        } catch (err) {
          console.error("Erro ao fazer fetch de membros:", err);
          return message.reply("⚠️ Não consegui obter a lista de membros do cargo. Tenta novamente.");
        }
      }

      const members = role.members?.filter((m) => !m.user.bot);
      const total = members?.size || 0;

      if (total === 0) {
        return message.reply("ℹ️ Esse cargo não tem membros (ou apenas bots).");
      }

      // 6) Feedback inicial
      const statusMsg = await message.reply(
        `🚀 A enviar DMs para **${total}** membro(s) com o cargo **${role.name}**...`
      );

      // 7) Enviar DM sequencialmente com delay
      let enviados = 0;
      let falhados = 0;

      for (const [, member] of members) {
        try {
          await member.user.send(msgText);
          enviados++;
        } catch (err) {
          // DMs fechadas, user bloqueou, sem servidor em comum, etc.
          falhados++;
        }
        // Pequeno delay para não bater rate limit agressivo
        // eslint-disable-next-line no-await-in-loop
        await wait(DM_DELAY_MS);
      }

      lastRun = now;

      // 8) Resumo final
      const embed = new EmbedBuilder()
        .setTitle("Resumo do envio de DMs")
        .setDescription(
          `**Cargo:** ${role}\n**Total:** ${total}\n**Enviadas:** ${enviados}\n**Falhadas:** ${falhados}`
        )
        .setColor(falhados > 0 ? 0xffcc00 : 0x57f287) // amarelo se houve falhas, verde se tudo ok
        .setTimestamp();

      await statusMsg.edit({ content: "✅ Concluído.", embeds: [embed] });
    } catch (e) {
      console.error(e);
      return message.reply("❌ Erro inesperado ao executar o comando.");
    }
  },
};

function wait(ms) {
  return new Promise((res) => setTimeout(res, ms));
}
