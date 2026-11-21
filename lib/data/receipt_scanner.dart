import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

const _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
const _model = 'claude-sonnet-5-5';

const _prompt = '''
This is a photo of a restaurant/cafe/shop receipt (often Arabic, Egyptian). Extract its lines.
Reply with ONLY a JSON object, no other text, in this exact shape:
{"items":[{"name":"...","price":0.0}],"service":0.0,"tax":0.0,"discount":0.0,"total":0.0}
Rules:
- "price" is the full line total (quantity x unit price) in Egyptian pounds.
- Keep item names exactly as printed (do not translate).
- Do not put service charge, tax or discount inside items.
- "total" is the final amount to pay. Use 0 for any value not on the receipt.
- If the image is not a receipt, reply {"error":"not_a_receipt"}.
''';

class ScanItem {
  ScanItem({required this.name, required this.price, required this.assignees});
  String name;
  int price; 
  final Set<String> assignees;
}

class ScanResult {
  const ScanResult(this.items, this.total);
  final List<ScanItem> items;
  final int total; 
}

class ReceiptScanException implements Exception {
  const ReceiptScanException(this.message);
  final String message;
}

Future<ScanResult> scanReceipt(XFile file, Set<String> everyone) async {
  if (_apiKey.isEmpty) {
    throw const ReceiptScanException(
      'مفتاح الذكاء الاصطناعي ناقص. شغّل التطبيق بـ --dart-define=ANTHROPIC_API_KEY=...');
  }
  final bytes = await file.readAsBytes();
  final mime = file.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
  final res = await http.post(
    Uri.parse('https://api.anthropic.com/v1/messages'),
    headers: {
      'x-api-key': _apiKey,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: jsonEncode({
      'model': _model,
      'max_tokens': 2000,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'image', 'source': {'type': 'base64', 'media_type': mime, 'data': base64Encode(bytes)}},
            {'type': 'text', 'text': _prompt},
          ],
        }
      ],
    }),
  ).timeout(const Duration(seconds: 90));

  if (res.statusCode == 401) throw const ReceiptScanException('مفتاح API غلط أو منتهي');
  if (res.statusCode != 200) {
    throw ReceiptScanException('الخدمة رجّعت خطأ (${res.statusCode}). اتأكد من الرصيد في حساب API.');
  }
  final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  final text = (body['content'] as List).where((c) => c['type'] == 'text').map((c) => c['text']).join();
  return _parse(text, everyone);
}

ScanResult _parse(String text, Set<String> everyone) {
  const bad = ReceiptScanException('مقدرتش أفهم الفاتورة، جرّب صورة أوضح');
  final a = text.indexOf('{'), b = text.lastIndexOf('}');
  if (a < 0 || b <= a) throw bad;
  dynamic decoded;
  try {
    decoded = jsonDecode(text.substring(a, b + 1));
  } catch (_) {
    throw bad;
  }
  if (decoded is! Map<String, dynamic>) throw bad;
  final j = decoded;
  if (j['error'] != null) {
    throw const ReceiptScanException('الصورة دي مش باين إنها فاتورة. جرّب صورة أوضح.');
  }
  int p(dynamic v) => (((v as num?)?.toDouble() ?? 0) * 100).round();

  final items = <ScanItem>[];
  for (final raw in (j['items'] as List? ?? [])) {
    final m = raw as Map<String, dynamic>;
    final price = p(m['price']);
    if (price <= 0) continue;
    items.add(ScanItem(name: (m['name'] ?? 'صنف').toString(), price: price, assignees: {...everyone}));
  }
  if (items.isEmpty) throw bad;
  final sum = items.fold<int>(0, (s, i) => s + i.price);
  var total = p(j['total']);
  if (total <= 0) total = sum + p(j['service']) + p(j['tax']) - p(j['discount']);
  return ScanResult(items, total);
}