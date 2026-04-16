import os
import re

with open('lib/seller_dashboard.dart', 'r', encoding='utf-8') as f:
    content = f.read()

start_idx = content.find('void _processVoiceCommand(String command)')
if start_idx == -1:
    print('Function not found')
    exit(1)

next_func_idx = content.find('Widget build(BuildContext context)', start_idx)
end_idx = content.rfind('}', start_idx, next_func_idx) + 1

new_func = """void _processVoiceCommand(String command) {
    if (command.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('?????? ???????')),
      );
      return;
    }

    String productName = "";
    double weight = 1.0;
    int totalPrice = 0;

    final weightRegExp = RegExp(r'(????|???|????????|???|?????|??????|??????|????|??????|????|????|??????|?????|?????|???|1|2|3|4|5|6)\s*????');
    final weightMatch = weightRegExp.firstMatch(command);

    String textWithoutWeight = command;

    if (weightMatch != null) {
      final weightStr = weightMatch.group(1)!;
      if (weightStr == '????') weight = 0.25;
      else if (weightStr == '???') weight = 0.5;
      else if (weightStr == '????????') weight = 0.75;
      else if (weightStr == '???' || weightStr == '?????' || weightStr == '1') weight = 1.0;
      else if (weightStr == '??????' || weightStr == '??????' || weightStr == '2') weight = 2.0;
      else if (weightStr == '????' || weightStr == '??????' || weightStr == '????' || weightStr == '3') weight = 3.0;
      else if (weightStr == '????' || weightStr == '??????' || weightStr == '4') weight = 4.0;
      else if (weightStr == '?????' || weightStr == '?????' || weightStr == '5') weight = 5.0;
      else if (weightStr == '???' || weightStr == '6') weight = 6.0;

      textWithoutWeight = command.replaceFirst(weightMatch.group(0)!, '').trim();
    }

    String parsedPriceText = textWithoutWeight;
    final tamilNumbers = {
      '???????? ?????': '25',
      '????????? ?????': '35',
      '?????????': '15',
      '????????': '90',
      '????????': '300',
      '???????': '200',
      '?????': '500',
      '??????': '400',
      '??????': '1000',
      '??????': '2',
      '??????': '2',
      '??????': '3',
      '????': '3',
      '????': '3',
      '??????': '4',
      '????': '4',
      '?????': '5',
      '?????': '5',
      '?????': '10',
      '??????': '20',
      '???????': '30',
      '???????': '40',
      '??????': '50',
      '??????': '50',
      '??????': '60',
      '??????': '70',
      '??????': '80',
      '??????': '80',
      '????': '100',
      '??????': '100',
      '?????': '1',
      '?????': '1',
      '???': '6',
      '???': '7',
      '?????': '8',
      '??????': '9',
    };

    for (final key in tamilNumbers.keys) {
      if (parsedPriceText.contains(key)) {
        parsedPriceText = parsedPriceText.replaceAll(key, tamilNumbers[key]!);
      }
    }

    final priceRegExp = RegExp(r'\d+');
    final priceMatch = priceRegExp.firstMatch(parsedPriceText);

    if (priceMatch != null) {
      final totalPriceStr = priceMatch.group(0)!;
      totalPrice = int.tryParse(totalPriceStr) ?? 0;

      productName = textWithoutWeight;
      for (final key in tamilNumbers.keys) {
         productName = productName.replaceAll(key, '');
      }
      productName = productName.replaceAll(totalPriceStr, '')
                              .replaceAll('??????', '')
                              .replaceAll('????', '')
                              .trim();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('?????? ??????????? (\$textWithoutWeight)')),
      );
      return;
    }

    if (productName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('?????? ??????????? (\$textWithoutWeight)')),
      );
      return;
    }

    double perKgPrice = totalPrice / weight;
    String perKgStr = (perKgPrice == perKgPrice.toInt())
        ? perKgPrice.toInt().toString()
        : perKgPrice.toStringAsFixed(2);

    setState(() {
      demoProducts.insert(0, {
        'name': productName,
        'weight': weight.toString(),
        'per_kg_price': perKgStr,
        'total_price': totalPrice.toString(),
        'price': _formatPriceDisplay(weight, totalPrice)
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${productName} ???????????????')),
    );
  }
"""

new_content = content[:start_idx] + new_func + content[end_idx:]

with open('lib/seller_dashboard.dart', 'w', encoding='utf-8') as f:
    f.write(new_content)

print('Replaced logic!')
