<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

function respond(array $payload, int $status = 200): void {
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit;
}

$raw = file_get_contents('php://input');
if ($raw === false) {
    respond(['success' => false, 'message' => 'Pedido inválido.'], 400);
}

$data = json_decode($raw, true);
if (!is_array($data)) {
    respond(['success' => false, 'message' => 'Formato de dados inválido.'], 400);
}

$nome = trim((string)($data['nome'] ?? ''));
$email = trim((string)($data['email'] ?? ''));
$telefone = trim((string)($data['telefone'] ?? ''));
$mensagem = trim((string)($data['mensagem'] ?? ''));
$hp = trim((string)($data['hp'] ?? $data['website'] ?? ''));

if ($hp !== '') {
    respond(['success' => true, 'message' => 'OK']);
}

if ($nome === '' || $email === '' || $mensagem === '') {
    respond(['success' => false, 'message' => 'Campos obrigatórios em falta.'], 422);
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    respond(['success' => false, 'message' => 'Indique um email válido.'], 422);
}

$nome = substr(strip_tags($nome), 0, 120);
$telefone = substr(strip_tags($telefone), 0, 40);
$mensagem = substr(strip_tags($mensagem), 0, 5000);

$to = 'xyz23comercial@gmail.com';
$subject = 'Novo pedido de orçamento — Site XYZ';
$bodyLines = [
    "Nome: {$nome}",
    "Email: {$email}",
    "Telefone: {$telefone}",
    '',
    'Mensagem:',
    $mensagem,
];
$body = implode("\n", $bodyLines) . "\n";

$headers = "From: noreply@tornosxyz.pt\r\n";
$headers .= "Reply-To: {$email}\r\n";
$headers .= "Content-Type: text/plain; charset=UTF-8\r\n";

$ok = @mail($to, $subject, $body, $headers);

$logLine = sprintf(
    "%s | %s <%s> | %s | %s\n",
    date('Y-m-d H:i:s'),
    $nome,
    $email,
    $telefone !== '' ? $telefone : 'sem telefone',
    $_SERVER['REMOTE_ADDR'] ?? 'ip-desconhecido'
);
@file_put_contents(__DIR__ . '/mail.log', $logLine, FILE_APPEND);

if ($ok) {
    respond(['success' => true, 'message' => 'Mensagem enviada. Obrigado!']);
}

respond(['success' => false, 'message' => 'Não foi possível enviar. Tente novamente.'], 500);
