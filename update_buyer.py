import os

content = """import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

import 'seller_dashboard.dart';

class BuyerDashboardScreen extends StatefulWidget {
  const BuyerDashboardScreen({super.key});

  @override
  State<BuyerDashboardScreen> createState() => _BuyerDashboardScreenState();
}

class _BuyerDashboardScreenState extends State<BuyerDashboardScreen> {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _isListening = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("ta-IN");
  }

  List<Map<String, String>> get _filteredProducts {
    if (_searchQuery.isEmpty) return demoProducts;
    return demoProducts.where((p) => p['name']!.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  Future<void> _processPurchase(Map<String, String> product, double quantity, double totalPrice) async {
    const url = 'http://127.0.0.1:5000/orders';
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'product_name': product['name'],
          'quantity': quantity.toString(),
          'total_price': totalPrice.toStringAsFixed(2),
        }),
      );
      
      if (!mounted) return;
      Navigator.pop(context); // Close loader

      if (response.statusCode == 201) {
        await _flutterTts.speak("?????? ?????? ????? ?????????????");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('?????? ??????!', style: TextStyle(fontSize: 18)),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('???? ?????????', style: TextStyle(fontSize: 18))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('??????? ????: $e')));
    }
  }

  void _showQuantityDialog(Map<String, String> product) {
    double perKgPrice = double.tryParse(product['per_kg_price'] ?? '0') ?? 0;
    if (perKgPrice == 0) {
      perKgPrice = double.tryParse(product['total_price'] ?? '0') ?? 0;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double selectedQuantity = 1.0;
            double totalPrice = perKgPrice * selectedQuantity;

            return AlertDialog(
              title: Text(product['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('??????? ?????????', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('???? ???? (0.25)', style: TextStyle(fontSize: 16)),
                        selected: selectedQuantity == 0.25,
                        onSelected: (val) {
                          if (val) setStateDialog(() => selectedQuantity = 0.25);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('??? ???? (0.5)', style: TextStyle(fontSize: 16)),
                        selected: selectedQuantity == 0.5,
                        onSelected: (val) {
                          if (val) setStateDialog(() => selectedQuantity = 0.5);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('??? ???? (1.0)', style: TextStyle(fontSize: 16)),
                        selected: selectedQuantity == 1.0,
                        onSelected: (val) {
                          if (val) setStateDialog(() => selectedQuantity = 1.0);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '????? ????: ?${(perKgPrice * selectedQuantity).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 10),
                  const Text('????? ????????????????', style: TextStyle(fontSize: 16)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('?????', style: TextStyle(fontSize: 18)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    _processPurchase(product, selectedQuantity, perKgPrice * selectedQuantity);
                  },
                  child: const Text('????? ????', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize(
        onError: (error) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('?????? ???????', style: TextStyle(fontSize: 18))));
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          localeId: 'ta_IN',
          onResult: (result) {
            setState(() {
              String words = result.recognizedWords;
              String query = words.replaceAll('??????', '').replaceAll('??????', '').trim();
              _searchQuery = query;
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speechToText.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: AppBar(
        title: const Text('?????????? ?????', style: TextStyle(fontWeight: FontWeight.bold)),        
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _searchQuery = ''),
            )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: products.isEmpty
                ? const Center(
                    child: Text(
                      '?????? ?????????????',
                      style: TextStyle(fontSize: 22, color: Colors.grey, fontWeight: FontWeight.bold), 
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: products.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      String displayPrice = product['per_kg_price'] != null && product['per_kg_price']!.isNotEmpty 
                          ? '?${product['per_kg_price']} / ??? ????' 
                          : '?${product['total_price']} / ??? ????';

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBinding(borderRadius: BorderRadius.circular(12)),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            title: Text(
                              product['name']!,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                displayPrice, 
                                style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 18)
                              ),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBinding(borderRadius: BorderRadius.circular(8))
                              ),
                              onPressed: () => _showQuantityDialog(product),    
                              child: const Text('?????', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ]
            ),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isListening ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBinding(borderRadius: BorderRadius.circular(12))
                ),
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 28),
                label: Text(
                  _isListening ? '?????????...' : '???????',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                onPressed: _listen,
              ),
            ),
          )
        ],
      ),
    );
  }
}
"""
with open('lib/buyer_dashboard.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
