import os
import re

with open("lib/seller_dashboard.dart", "r", encoding="utf-8") as f:
    content = f.read()

start = content.find("void _processVoiceCommand(String command)")
next_func = content.find("Widget build(BuildContext context)", start)
end = content.rfind("}", start, next_func) + 1

new_func = """void _processVoiceCommand(String command) {
    if (command.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('சரியாக பேசவும்')),
      );
      return;
    }

    String productName = "";
    double weight = 1.0;
    int totalPrice = 0;

    final weightRegExp = RegExp(r'(கால்|அரை|முக்கால்|ஒரு|ஒன்று|ரெண்டு|இரண்டு|மூணு|மூன்று|மூன்|நாலு|நான்கு|அஞ்சு|ஐந்து|ஆறு|1|2|3|4|5|6)\s*கிலோ');
    final weightMatch = weightRegExp.firstMatch(command);

    String textWithoutWeight = command;

    if (weightMatch != null) {
      final weightStr = weightMatch.group(1)!;
      if (weightStr == 'கால்') weight = 0.25;
      else if (weightStr == 'அரை') weight = 0.5;
      else if (weightStr == 'முக்கால்') weight = 0.75;
      else if (weightStr == 'ஒரு' || weightStr == 'ஒன்று' || weightStr == '1') weight = 1.0;
      else if (weightStr == 'ரெண்டு' || weightStr == 'இரண்டு' || weightStr == '2') weight = 2.0;
      else if (weightStr == 'மூணு' || weightStr == 'மூன்று' || weightStr == 'மூன்' || weightStr == '3') weight = 3.0;
      else if (weightStr == 'நாலு' || weightStr == 'நான்கு' || weightStr == '4') weight = 4.0;
      else if (weightStr == 'அஞ்சு' || weightStr == 'ஐந்து' || weightStr == '5') weight = 5.0;
      else if (weightStr == 'ஆறு' || weightStr == '6') weight = 6.0;

      textWithoutWeight = command.replaceFirst(weightMatch.group(0)!, '').trim();
    }

    String parsedPriceText = textWithoutWeight;
    final tamilNumbers = {
      'இருபத்தி ஐந்து': '25',
      'முப்பத்தி ஐந்து': '35',
      'பதினைந்து': '15',
      'தொண்ணூறு': '90',
      'முன்னூறு': '300',
      'இருநூறு': '200',
      'ஐநூறு': '500',
      'நானூறு': '400',
      'ஆயிரம்': '1000',
      'இரண்டு': '2',
      'ரெண்டு': '2',
      'மூன்று': '3',
      'மூணு': '3',
      'மூன்': '3',
      'நான்கு': '4',
      'நாலு': '4',
      'ஐந்து': '5',
      'அஞ்சு': '5',
      'பத்து': '10',
      'இருபது': '20',
      'முப்பது': '30',
      'நாற்பது': '40',
      'ஐம்பது': '50',
      'அம்பது': '50',
      'அறுபது': '60',
      'எழுபது': '70',
      'எண்பது': '80',
      'எம்பது': '80',
      'நூறு': '100',
      'நூத்தி': '100',
      'ஒன்று': '1',
      'ஒன்னு': '1',
      'ஆறு': '6',
      'ஏழு': '7',
      'எட்டு': '8',
      'ஒன்பது': '9',
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
                              .replaceAll('ரூபாய்', '')
                              .replaceAll('ரூபா', '')
                              .trim();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('பொருள் புரியவில்லை (\$textWithoutWeight)')),
      );
      return;
    }

    if (productName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('பொருள் புரியவில்லை (\$textWithoutWeight)')),
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
      SnackBar(content: Text('${productName} சேர்க்கப்பட்டது')),
    );
  }
"""

with open("lib/seller_dashboard.dart", "w", encoding="utf-8") as f:
    f.write(content[:start] + new_func + content[end:])
print("Fixed!")
