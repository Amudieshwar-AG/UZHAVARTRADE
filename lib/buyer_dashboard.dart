import 'dart:convert';
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
    return demoProducts.where((p) => (p['name'] ?? 'தகவல் இல்லை').toLowerCase().contains(_searchQuery.toLowerCase())).toList();
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
          'product_name': product['name'] ?? "தகவல் இல்லை",
          'quantity': quantity.toString(),
          'total_price': totalPrice.toStringAsFixed(2),
        }),
      );
      
      if (!mounted) return;
      Navigator.pop(context); // Close loader

      if (response.statusCode == 201) {
        await _flutterTts.speak("ஆர்டர் வெற்றி");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ஆர்டர் வெற்றி!', style: TextStyle(fontFamily: 'NotoSansTamil', fontSize: 18)),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ஆர்டர் தோல்வி', style: TextStyle(fontFamily: 'NotoSansTamil', fontSize: 18))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('பிழை: $e', style: const TextStyle(fontFamily: 'NotoSansTamil'))));
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

            return AlertDialog(
              title: Text(product['name'] ?? "தகவல் இல்லை", style: const TextStyle(fontFamily: 'NotoSansTamil', fontWeight: FontWeight.bold, fontSize: 24)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('இந்த பொருளை வாங்க விரும்புகிறீர்களா?', style: TextStyle(fontFamily: 'NotoSansTamil', fontSize: 18)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('கால் கிலோ (0.25)', style: TextStyle(fontFamily: 'NotoSansTamil', fontSize: 16)),
                        selected: selectedQuantity == 0.25,
                        onSelected: (val) {
                          if (val) setStateDialog(() => selectedQuantity = 0.25);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('அரை கிலோ (0.5)', style: TextStyle(fontFamily: 'NotoSansTamil', fontSize: 16)),
                        selected: selectedQuantity == 0.5,
                        onSelected: (val) {
                          if (val) setStateDialog(() => selectedQuantity = 0.5);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('ஒரு கிலோ (1.0)', style: TextStyle(fontFamily: 'NotoSansTamil', fontSize: 16)),
                        selected: selectedQuantity == 1.0,
                        onSelected: (val) {
                          if (val) setStateDialog(() => selectedQuantity = 1.0);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'மொத்த விலை: ₹${(perKgPrice * selectedQuantity).toStringAsFixed(2)}',
                    style: const TextStyle(fontFamily: 'NotoSansTamil', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('இல்லை', style: TextStyle(fontFamily: 'NotoSansTamil', fontSize: 18)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    _processPurchase(product, selectedQuantity, perKgPrice * selectedQuantity);
                  },
                  child: const Text('வாங்க', style: TextStyle(fontFamily: 'NotoSansTamil', fontSize: 18, fontWeight: FontWeight.bold)),
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('மைக்ரோஃபோன் பிழை', style: TextStyle(fontFamily: 'NotoSansTamil', fontSize: 18))));
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          localeId: 'ta_IN',
          onResult: (result) {
            setState(() {
              String words = result.recognizedWords;
              String query = words.replaceAll('காய்கறி', '').replaceAll('வேண்டும்', '').trim();
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
        title: const Text('வாங்குபவர் பகுதி', style: TextStyle(fontFamily: 'NotoSansTamil', fontWeight: FontWeight.bold)),        
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
                      'தகவல் இல்லை',
                      style: TextStyle(fontFamily: 'NotoSansTamil', fontSize: 22, color: Colors.grey, fontWeight: FontWeight.bold), 
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: products.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      // Show per 1 kg price always as requested
                      String displayPrice = '';
                      if (product['per_kg_price'] != null && product['per_kg_price']!.isNotEmpty) {
                        displayPrice = '₹${product['per_kg_price']} / ஒரு கிலோ';
                      } else {
                        double perKgPrice = double.tryParse(product['total_price'] ?? '0') ?? 0;
                        String perKgStr = perKgPrice == perKgPrice.toInt() ? perKgPrice.toInt().toString() : perKgPrice.toStringAsFixed(2);
                        displayPrice = '₹$perKgStr / ஒரு கிலோ';
                      }

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            title: Text(
                              product['name'] ?? "தகவல் இல்லை",
                              style: const TextStyle(fontFamily: 'NotoSansTamil', fontSize: 22, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                displayPrice, 
                                style: const TextStyle(fontFamily: 'NotoSansTamil', color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 18)
                              ),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                              ),
                              onPressed: () => _showQuantityDialog(product),    
                              child: const Text('வாங்க', style: TextStyle(fontFamily: 'NotoSansTamil', fontSize: 18, fontWeight: FontWeight.bold)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 28),
                label: Text(
                  _isListening ? 'கேட்கிறது...' : '🎤 பேசவும்',
                  style: const TextStyle(fontFamily: 'NotoSansTamil', fontSize: 22, fontWeight: FontWeight.bold),
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
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

import 'seller_dashboard.dart';

class BuyerDashboardScreen extends StatefulWidget |
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
    return demoProducts.where((p) => (p['name'] ?? 'धकया���ल्ला').toLowerCase().contains(_searchQuery.toLowerCase())).toList();
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
          "product_name": product['name'] ?? "धकया���ल्ला",
          "quantity": quantity.toString(),
          "total_price": totalPrice.toStringAsFixed(2),
        }),
      );
      
      if (!mounted) return;
      Navigator.pop(context); // Close loader

      if (response.statusCode == 201) {
        await _flutterTts.speak("अाल्टल् वेऱ्रि");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('थार्टर् ॅेर्रॿ'!, style: TextStyle(fontSize: 18)),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('थार्टर् तेाल्वि', style: TextStyle(fontSize: 18))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(NackBar(content: Text()पिसै: $e')));
    }
  }

  void _showQuantityDialog(Map<String, String> product) {
    doubld perKgPrice = double.tryParse(product['per_kg_price'] ?? '0') ?? 0;
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
              title: Text(product['name'] ?? "धकया���ल्ला", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text()अऱवै थ्दॷर्न्थॆटम्कवम्', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('काल् किलै (0.25)', style: TextStyle(fontSize: 16)),
                        selected: selectedQuantity == 0.25,
                        onSelected: (val) {
                          if (val) setStateDialog(() => selectedQuantity = 0.25);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('अरै किलै (0.5)', style: TextStyle(fontSize: 16)),
                        selected: selectedQuantity == 0.5,
                        onSelected: (val) {
                          if (val) setStateDialog(() => selectedQuantity = 0.5);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('षरु किलै (1.0)', style: TextStyle(fontSize: 16)),
                        selected: selectedQuantity == 1.0,
                        onSelected: (val) {
                          if (val) setStateDialog() => selectedQuantity = 1.0);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'मॊथ्थ विलॆ: ₹${(perKgPrice * selectedQuantity).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 10),
                  const Text('इन्थ पऩरुलॆ व`��क्क विरु म्रिलौथेर्कलफ़ेल?', style: TextStyle(fontSize: 16)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('अल्लॆ', style: TextStyle(fontSize: 18)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    _processPurchase(product, selectedQuantity, perKcPrice * selectedQuantity);
                  },
                  child: const Text('षा��कऱ�, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⤮ॉक्रॻ्ळॿॏधषॆ पिवै', style: TextStyle(fontSize: 18))));
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          localeId: 'ta_IN',
          onResult: (result) {
            setState(() {
              String words = result.recognizedWords;
              String query = words.replaceAll()काय्कष', '').replaceAll((वेण्टुo', '').trim();
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
        title: const Text('वـाण्कुनवर् पक्`��ि', style: TextStyle(fontWeight: FontWeight.bold)),        
        backgroundColor: const Color(0xF�������(����������ɕ�ɽչ�
�����
����̹ݡ�є�(����������ѥ����l(��������������}͕�ɍ�EՕ�乥�9������(������������%���	��ѽ��(������������������聍���Ё%����%���̹����Ȥ�(����������������Aɕ�͕�耠�����͕�Mхє�������}͕�ɍ�EՕ��􀜜��(�������������(��������t�(��������(�����������
��յ��(�������������ɕ��l(������������������(�������������������ɽ�Ս�̹������(����������������������Ё
��ѕȠ(����������������������������Q��Р(������������������������������W���������˂�7��˂����(��������������������������屔�Q���M�屔�����M����Ȱ�������
����̹�ɕ䰁����]���������]����й�������(������������������������(���������������������(�����������������1���Y��ܹ͕��Ʌѕ��(���������������������������聍���Ё���%�͕�̹�����Ȥ�(���������������������ѕ�
�չ���ɽ�Ս�̹����Ѡ�(��������������������͕��Ʌѽ�	ե����耡���ѕ�а�����ऀ�������ЁM�镑	�ࡡ������र(���������������������ѕ�	ե����耡���ѕ�а�����ँ�(�����������������������������ɽ�ՍЀ��ɽ�Ս��m�����t�(����������������������M�ɥ����������Aɥ�����ɽ�Ս�l����}��}�ɥ���t���ձ������ɽ�Ս�l����}��}�ɥ���t����9������(������������������������������
���ɽ�Ս�l����}��}�ɥ���u􀼃�����Â����W�����˂� ��(��������������������������耟�
���ɽ�Ս�l�ѽх�}�ɥ���u􀼃�����Â����W�����˂�$��((����������������������ɕ��ɸ�
�ɐ�(���������������������������مѥ���Ȱ(������������������������͡����I�չ���I��х����	�ɑ�ȡ��ɑ��I������	�ɑ��I����̹��ɍձ�Ƞ�Ȥ��(������������������������������
����̹ݡ�є�(������������������������������A�������(���������������������������������聍���Ё���%�͕�̹�嵵��ɥ��ٕ�ѥ��������(��������������������������������1���Q����(����������������������������ѥѱ��Q��Р(�������������������������������ɽ�Ս�l������t����������W���������˂�7��˂����(��������������������������������屔聍���ЁQ���M�屔�����M����Ȱ�����]���������]����й������(������������������������������(�����������������������������Չѥѱ��A�������(�������������������������������������聍���Ё���%�͕�̹����ѽ��и���(������������������������������������Q��Р(���������������������������������������Aɥ����(����������������������������������屔聍���ЁQ���M�屔�������
���Ƞ�����Ȥ������]���������]����й����������M�����(��������������������������������(������������������������������(�����������������������������Ʌ��������مѕ�	��ѽ��(��������������������������������屔���مѕ�	��ѽ����展ɽ��(���������������������������������������聍���Ё���%�͕�̹�嵵��ɥ����ɥ齹х������ٕ�ѥ�����Ȥ�(�������������������������������������ɽչ�
����聍���Ё
���Ƞ���
����(����������������������������������ɕ�ɽչ�
�����
����̹ݡ�є�(��������������������������������͡����I�չ���I��х����	�ɑ�ȡ��ɑ��I������	�ɑ��I����̹��ɍձ�Ƞत(��������������������������������(��������������������������������Aɕ�͕�耠�����}͡��EՅ�ѥ���������ɽ�ՍФ�����(�����������������������������������聍���ЁQ��Р���߂������W���ܰ���屔�Q���M�屔�����M����ఁ����]���������]����й�������(������������������������������(����������������������������(��������������������������(������������������������(����������������������(��������������������(������������(����������
��х���Ƞ(�������������������聍���Ё���%�͕�̹�����ؤ�(����������������Ʌѥ���	�����Ʌѥ���(��������������������
����̹ݡ�є�(�����������������M������l(����������������	��M����ܠ(������������������������
����̹������ݥѡ=���������Ԥ�(����������������������I���������(���������������������͕�聍���Ё=��͕Р����Ԥ�(�����������������(��������������t(��������������(������������������M�镑	��(��������������ݥ�Ѡ聑�Չ�����������(������������������������(����������������������مѕ�	��ѽ�������(������������������屔���مѕ�	��ѽ����展ɽ��(�����������������������ɽչ�
�����}��1��ѕ�������
����̹ɕ���
����̹��Ք�(��������������������ɕ�ɽչ�
�����
����̹ݡ�є�(������������������͡����I�չ���I��х����	�ɑ�ȡ��ɑ��I������	�ɑ��I����̹��ɍձ�Ƞ�Ȥ�(������������������(���������������������%����}��1��ѕ�������%���̹�����%���̹���}������ͥ���र(����������������������Q��Р(������������������}��1��ѕ����������W������7��W��3��Â�������耟�~:������������ׂ������(��������������������屔聍���ЁQ���M�屔�����M����Ȱ�����]���������]����й������(������������������(������������������Aɕ�͕��}���ѕ��(����������������(��������������(�����������(��������t�(��������(������(���)�