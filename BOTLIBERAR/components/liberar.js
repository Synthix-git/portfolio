const {
    ActionRowBuilder,
    ButtonBuilder,
    ButtonStyle,
    ModalBuilder,
    TextInputBuilder,
    TextInputStyle,
    EmbedBuilder,
    InteractionType
} = require('discord.js');
const mysql = require('mysql2/promise');
const config = require('../config.json');

const db = mysql.createPool(config.mysql);

// IDs dos cargos para remoção/adição
const cargoRemoverId = '888367113604067356'; // Aguardando Liberação
const cargoAdicionarId = '1401653403805028383'; // Whitelist Liberado

// Canal de logs
const logChannelId = 'IDCANALDELOGS';

// Flag para evitar múltiplos listeners
let interactionListenerAttached = false;

module.exports = async function sendLiberarMessage(client) {
    const channel = await client.channels.fetch(config.channelLiberarId);
    if (!channel) return console.log("❌ Canal não encontrado.");

    // helper de log
    const sendLog = async (content) => {
        try {
            const logChannel = await client.channels.fetch(logChannelId);
            if (!logChannel) return console.log("⚠️ Canal de logs não encontrado:", logChannelId);
            await logChannel.send({ content });
        } catch (e) {
            console.log("⚠️ Falha ao enviar log:", e.message);
        }
    };

    // 🧹 Limpa mensagens anteriores do bot
    try {
        const messages = await channel.messages.fetch({ limit: 100 });
        const botMessages = messages.filter(msg => msg.author.id === client.user.id);
        if (botMessages.size > 0) {
            await channel.bulkDelete(botMessages, true);
        }
    } catch (err) {
        console.log("⚠️ Não foi possível limpar mensagens anteriores:", err.message);
    }

    // 📩 Envia mensagem com botão
    const embed = new EmbedBuilder()
        .setTitle("🔓 Liberação de Whitelist")
        .setDescription("Clica no botão abaixo e informa o **teu ID do servidor** para liberar o acesso.")
        .setColor(0x2ECC71);

    const row = new ActionRowBuilder().addComponents(
        new ButtonBuilder()
            .setCustomId("liberar_button")
            .setLabel("Liberar Acesso")
            .setStyle(ButtonStyle.Success)
    );

    await channel.send({ embeds: [embed], components: [row] });

    // ✅ Garante que só adicionamos o listener uma vez
    if (interactionListenerAttached) return;
    interactionListenerAttached = true;

    // 🎯 Listener principal de interações
    client.on('interactionCreate', async interaction => {
        if (interaction.isButton() && interaction.customId === 'liberar_button') {
            const modal = new ModalBuilder()
                .setCustomId('liberar_modal')
                .setTitle('Confirmação de Whitelist')
                .addComponents(
                    new ActionRowBuilder().addComponents(
                        new TextInputBuilder()
                            .setCustomId('player_id')
                            .setLabel('Qual é o teu ID do servidor?')
                            .setStyle(TextInputStyle.Short)
                            .setPlaceholder('Ex: 17')
                            .setRequired(true)
                    )
                );

            return interaction.showModal(modal);
        }

        if (interaction.type === InteractionType.ModalSubmit && interaction.customId === 'liberar_modal') {
            // 1) ACK imediato (evita 10062)
            try {
                await interaction.deferReply({ ephemeral: true });
            } catch (ackErr) {
                // se falhar aqui, não conseguimos responder de qualquer forma
                console.error("❌ Falha ao deferReply do modal:", ackErr);
                return;
            }

            const input = interaction.fields.getTextInputValue('player_id').trim();
            const onlyDigits = /^\d+$/;

            if (!onlyDigits.test(input)) {
                await sendLog(`<@${interaction.user.id}> tentou liberar com **ID inválido**: \`${input}\`.`);
                return interaction.editReply('❌ ID inválido. Usa apenas números.');
            }

            const id = Number(input);

            try {
                const [rows] = await db.query("SELECT * FROM accounts WHERE id = ?", [id]);

                if (rows.length === 0) {
                    await sendLog(`<@${interaction.user.id}> tentou liberar **ID inexistente**: \`${id}\`.`);
                    return interaction.editReply("❌ ID não encontrado na base de dados.");
                }

                const conta = rows[0];

                if (conta.whitelist === 1) {
                    await sendLog(`<@${interaction.user.id}> tentou liberar **ID já liberado**: \`${id}\`.`);
                    return interaction.editReply("❌ Esse ID já foi verificado anteriormente.");
                }

                await db.query("UPDATE accounts SET whitelist = 1 WHERE id = ?", [id]);

                const member = await interaction.guild.members.fetch(interaction.user.id);

                // 🔁 Atualiza o nickname removendo qualquer | ID anterior
                const currentName = member.displayName || member.user.username;
                const cleanedName = currentName.replace(/\|\s*\d+$/, '').trim();
                const newNick = `${cleanedName} | ${id}`;

                let nickChanged = true;
                try {
                    await member.setNickname(newNick);
                } catch (err) {
                    nickChanged = false;
                    console.log("⚠️ Não foi possível alterar o nickname:", err.message);
                    await sendLog(`⚠️ <@${interaction.user.id}> liberou \`${id}\`, **mas falhou ao alterar nickname** (${err.message}).`);
                }

                // 🧷 Troca de cargos
                let rolesChanged = true;
                try {
                    if (member.roles.cache.has(cargoRemoverId)) {
                        await member.roles.remove(cargoRemoverId);
                    }

                    if (!member.roles.cache.has(cargoAdicionarId)) {
                        await member.roles.add(cargoAdicionarId);
                    }
                } catch (err) {
                    rolesChanged = false;
                    console.log("⚠️ Erro ao gerenciar cargos:", err.message);
                    await sendLog(`⚠️ <@${interaction.user.id}> liberou \`${id}\`, **mas falhou ao gerenciar cargos** (${err.message}).`);
                }

                await sendLog(`✅ <@${interaction.user.id}> **liberou** o ID \`${id}\`${nickChanged ? '' : ' (nickname não alterado)'}${rolesChanged ? '' : ' (cargos não atualizados)'} .`);

                return interaction.editReply(`✅ Whitelist aplicada com sucesso ao ID \`${id}\`.`);

            } catch (err) {
                console.error("❌ Erro ao aplicar whitelist:", err);
                await sendLog(`❌ <@${interaction.user.id}> **falhou** ao liberar o ID \`${id}\`: ${err.message}`);
                return interaction.editReply("❌ Ocorreu um erro ao aplicar whitelist.");
            }
        }
    });
};
