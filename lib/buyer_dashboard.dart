import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/api_service.dart';

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
    await _flutterTts.setLanguage('ta-IN');
  }

  List<Map<String, String>> get _filteredProducts {
    if (_searchQuery.isEmpty) return demoProducts;
    return demoProducts
        .where(
          (p) => (p['name'] ?? 'தகவல் இல்லை').toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  Future<void> _initiateUPIPayment(
    Map<String, String> product,
    double quantity,
    double totalPrice,
  ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/sellers'),
      );
      if (!mounted) return;
      Navigator.pop(context); // close loader

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> sellers = responseData['sellers'] ?? [];
        if (sellers.isNotEmpty) {
          final seller = sellers[0];
          final String sellerName = seller['name'] ?? 'விற்பனையாளர்';
          final String sellerUpiId = seller['upi_id'] ?? 'default@upi';

          final Uri upiUri = Uri.parse(
            'upi://pay?pa=$sellerUpiId&pn=${Uri.encodeComponent(sellerName)}&am=${totalPrice.toStringAsFixed(2)}&cu=INR',
          );

          try {
            await launchUrl(upiUri, mode: LaunchMode.externalApplication);
          } catch (e) {
            print('Could not launch UPI app: $e');
            // Allow manual confirmation if device has no UPI apps (e.g., emulator)
          }

          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text(
                  'பணம் செலுத்திவிட்டீர்களா?',
                  style: TextStyle(
                    fontFamily: 'NotoSansTamil',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: const Text(
                  'பணம் செலுத்தியதை உறுதி செய்யவும்.',
                  style: TextStyle(fontFamily: 'NotoSansTamil', fontSize: 16),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                    },
                    child: const Text(
                      'இல்லை',
                      style: TextStyle(
                        color: Colors.red,
                        fontFamily: 'NotoSansTamil',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      _processPurchase(
                        product,
                        quantity,
                        totalPrice,
                        sellerName,
                        sellerUpiId,
                      );
                    },
                    child: const Text(
                      'ஆம்',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'NotoSansTamil',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('விற்பனையாளர் விவரங்கள் கிடைக்கவில்லை'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('பிணைய பிழை ஏற்ப்பட்டது')));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('பிழை: $e')));
    }
  }

  Future<void> _processPurchase(
    Map<String, String> product,
    double quantity,
    double totalPrice,
    String sellerName,
    String sellerUpiId,
  ) async {
    final url = '${ApiService.baseUrl}/orders';
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
          'product_name': product['name'] ?? 'தகவல் இல்லை',
          'quantity': quantity.toString(),
          'total_price': totalPrice.toStringAsFixed(2),
          'seller_name': sellerName,
          'seller_upi_id': sellerUpiId,
          'per_kg_price': product['per_kg_price']?.toString() ?? '',
          'buyer_name': 'வாடிக்கையாளர்',
        }),
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 201) {
        await _flutterTts.speak('ஆர்டர் வெற்றி');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ஆர்டர் வெற்றி!',
              style: TextStyle(fontFamily: 'NotoSansTamil', fontSize: 18),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ஆர்டர் தோல்வி',
              style: TextStyle(fontFamily: 'NotoSansTamil', fontSize: 18),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'பிழை: ',
            style: const TextStyle(fontFamily: 'NotoSansTamil'),
          ),
        ),
      );
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
        double selectedQuantity = 0.25;
        bool showMultipleMode = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                product['name'] ?? 'தகவல் இல்லை',
                style: const TextStyle(
                  fontFamily: 'NotoSansTamil',
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'இந்த பொருளை வாங்க விரும்புகிறீர்களா?',
                    style: TextStyle(fontFamily: 'NotoSansTamil', fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  if (!showMultipleMode)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text(
                            'கால் கிலோ (0.25)',
                            style: TextStyle(
                              fontFamily: 'NotoSansTamil',
                              fontSize: 16,
                            ),
                          ),
                          selected: selectedQuantity == 0.25,
                          onSelected: (val) {
                            if (val)
                              setStateDialog(() {
                                selectedQuantity = 0.25;
                              });
                          },
                        ),
                        ChoiceChip(
                          label: const Text(
                            'அரை கிலோ (0.5)',
                            style: TextStyle(
                              fontFamily: 'NotoSansTamil',
                              fontSize: 16,
                            ),
                          ),
                          selected: selectedQuantity == 0.5,
                          onSelected: (val) {
                            if (val)
                              setStateDialog(() {
                                selectedQuantity = 0.5;
                              });
                          },
                        ),
                        ChoiceChip(
                          label: const Text(
                            'முக்கால் கிலோ (0.75)',
                            style: TextStyle(
                              fontFamily: 'NotoSansTamil',
                              fontSize: 16,
                            ),
                          ),
                          selected: selectedQuantity == 0.75,
                          onSelected: (val) {
                            if (val)
                              setStateDialog(() {
                                selectedQuantity = 0.75;
                              });
                          },
                        ),
                        ChoiceChip(
                          label: const Text(
                            'ஒரு கிலோ (1.0)',
                            style: TextStyle(
                              fontFamily: 'NotoSansTamil',
                              fontSize: 16,
                            ),
                          ),
                          selected: selectedQuantity >= 1.0,
                          onSelected: (val) {
                            if (val) {
                              setStateDialog(() {
                                selectedQuantity = 1.0;
                                showMultipleMode = true;
                              });
                            }
                          },
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextButton.icon(
                          onPressed: () => setStateDialog(() {
                            showMultipleMode = false;
                            selectedQuantity = 0.25;
                          }),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text(
                            'திரும்ப',
                            style: TextStyle(fontFamily: 'NotoSansTamil'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(10, (index) {
                            final qty = (index + 1).toDouble();
                            return ChoiceChip(
                              label: Text(
                                '${qty.toInt()} கிலோ',
                                style: const TextStyle(
                                  fontFamily: 'NotoSansTamil',
                                  fontSize: 16,
                                ),
                              ),
                              selected: selectedQuantity == qty,
                              onSelected: (val) {
                                if (val) {
                                  setStateDialog(() => selectedQuantity = qty);
                                }
                              },
                            );
                          }),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  Text(
                    'மொத்த விலை: ₹${(perKgPrice * selectedQuantity).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontFamily: 'NotoSansTamil',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'இல்லை',
                    style: TextStyle(fontFamily: 'NotoSansTamil', fontSize: 18),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _initiateUPIPayment(
                      product,
                      selectedQuantity,
                      perKgPrice * selectedQuantity,
                    );
                  },
                  child: const Text(
                    'வாங்க',
                    style: TextStyle(
                      fontFamily: 'NotoSansTamil',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'மைக்ரோஃபோன் பிழை',
                style: TextStyle(fontFamily: 'NotoSansTamil', fontSize: 18),
              ),
            ),
          );
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          localeId: 'ta_IN',
          onResult: (result) {
            setState(() {
              String words = result.recognizedWords;
              String query = words
                  .replaceAll('காய்கறி', '')
                  .replaceAll('வேண்டும்', '')
                  .trim();
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
        title: const Text(
          'வாங்குபவர் பகுதி',
          style: TextStyle(
            fontFamily: 'NotoSansTamil',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _searchQuery = ''),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: products.isEmpty
                ? const Center(
                    child: Text(
                      'தகவல் இல்லை',
                      style: TextStyle(
                        fontFamily: 'NotoSansTamil',
                        fontSize: 22,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: products.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      String displayPrice = '';
                      if (product['per_kg_price'] != null &&
                          product['per_kg_price']!.isNotEmpty) {
                        displayPrice = '₹${product['per_kg_price']} / ஒரு கிலோ';
                      } else {
                        double perKgPrice =
                            double.tryParse(product['total_price'] ?? '0') ?? 0;
                        String perKgStr = perKgPrice == perKgPrice.toInt()
                            ? perKgPrice.toInt().toString()
                            : perKgPrice.toStringAsFixed(2);
                        displayPrice = '₹$perKgStr / ஒரு கிலோ';
                      }

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            title: Text(
                              product['name'] ?? 'தகவல் இல்லை',
                              style: const TextStyle(
                                fontFamily: 'NotoSansTamil',
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                displayPrice,
                                style: const TextStyle(
                                  fontFamily: 'NotoSansTamil',
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _showQuantityDialog(product),
                              child: const Text(
                                'வாங்க',
                                style: TextStyle(
                                  fontFamily: 'NotoSansTamil',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                  color: Colors.black.withAlpha(13),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isListening ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 28),
                label: Text(
                  _isListening ? 'கேட்கிறது...' : '🎤 பேசவும்',
                  style: const TextStyle(
                    fontFamily: 'NotoSansTamil',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _listen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
