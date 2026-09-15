/// Gera um payload no formato "Pix Copia e Cola" (BR Code / EMV QR Code),
/// seguindo a mesma estrutura de campos que os bancos usam de verdade
/// (Banco Central — Manual de Padrões para Iniciação do Pix). O código
/// resultante é estruturalmente válido (inclusive o checksum CRC16), mas
/// não está registrado em nenhum PSP/instituição real — então nenhum
/// banco vai efetivamente processar um pagamento a partir dele. É o
/// suficiente para gerar um QR Code Pix realista para fins de
/// demonstração/portfólio.
///
/// TODO(integração real): para gerar um QR Code que efetivamente recebe
/// pagamentos, a chave Pix e a cobrança precisam estar registradas junto
/// a uma instituição autorizada pelo Banco Central (PSP), normalmente via
/// API do próprio banco/adquirente.
class PixPayloadGenerator {
  PixPayloadGenerator._();

  static String generate({
    required String pixKey,
    required String merchantName,
    required String merchantCity,
    double? amount,
    String? description,
    String txId = '***',
  }) {
    final buffer = StringBuffer();

    buffer.write(_field('00', '01')); // Payload Format Indicator

    // Merchant Account Information — dados específicos do Pix.
    final gui = _field('00', 'br.gov.bcb.pix');
    final key = _field('01', pixKey);
    final desc = (description != null && description.trim().isNotEmpty)
        ? _field('02', _sanitize(description, maxLength: 40))
        : '';
    buffer.write(_field('26', '$gui$key$desc'));

    buffer.write(_field('52', '0000')); // Merchant Category Code
    buffer.write(_field('53', '986')); // Moeda: Real (BRL)

    if (amount != null && amount > 0) {
      buffer.write(_field('54', amount.toStringAsFixed(2)));
    }

    buffer.write(_field('58', 'BR')); // País
    buffer.write(_field('59', _sanitize(merchantName, maxLength: 25)));
    buffer.write(_field('60', _sanitize(merchantCity, maxLength: 15)));

    // Additional Data Field — identificador da transação (txid).
    final txField = _field('05', txId.isEmpty ? '***' : txId);
    buffer.write(_field('62', txField));

    // CRC16 é calculado sobre TODO o payload até aqui, já incluindo o
    // cabeçalho do próprio campo de CRC ("6304"), mas sem o valor do CRC.
    buffer.write('6304');
    final crc = _crc16(buffer.toString());
    buffer.write(crc);

    return buffer.toString();
  }

  static String _field(String id, String value) {
    final length = value.length.toString().padLeft(2, '0');
    return '$id$length$value';
  }

  static String _sanitize(String value, {required int maxLength}) {
    final cleaned = value.trim();
    return cleaned.length > maxLength ? cleaned.substring(0, maxLength) : cleaned;
  }

  /// CRC16-CCITT (polinômio 0x1021, valor inicial 0xFFFF) — o mesmo
  /// algoritmo usado no padrão EMV para o checksum do BR Code.
  static String _crc16(String data) {
    const polynomial = 0x1021;
    int crc = 0xFFFF;

    for (final byte in data.codeUnits) {
      crc ^= (byte << 8);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ polynomial) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }

    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}
