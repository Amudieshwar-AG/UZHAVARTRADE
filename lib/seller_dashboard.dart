import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'services/api_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

List<Map<String, String>> demoProducts = [];

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;

  // Text controllers for manual entry
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/products'),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> products = data['products'] ?? [];
        if (mounted) {
          setState(() {
            demoProducts = products
                .map(
                  (p) => {
                    'id': p['id']?.toString() ?? '',
                    'name': p['name']?.toString() ?? '',
                    'weight': p['weight']?.toString() ?? '',
                    'per_kg_price': p['per_kg_price']?.toString() ?? '',
                    'total_price': p['total_price']?.toString() ?? '',
                    'price': p['price']?.toString() ?? '',
                  },
                )
                .toList();
          });
        }
      }
    } catch (e) {
      print('Error fetching products: ');
    }
  }

  Future<void> _deleteProduct(int index, String productId) async {
    setState(() {
      demoProducts.removeAt(index);
    });

    if (productId.isNotEmpty) {
      try {
        final response = await http.delete(
          Uri.parse('${ApiService.baseUrl}/delete_product/$productId'),
        );
        if (response.statusCode != 200) {
          print('Failed to delete to database');
        }
      } catch (e) {
        print('Network Error deleting product: $e');
      }
    }
  }

  Future<void> _addNewProduct(Map<String, String> productMap) async {
    setState(() {
      demoProducts.insert(0, productMap);
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/add_product'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(productMap),
      );
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        setState(() {
          demoProducts[0]['id'] = data['id'].toString();
        });
      } else {
        print('Failed to save to database');
      }
    } catch (e) {
      print('Network Error saving product: $e');
    }
  }

  String _formatWeight(double w) {
    if (w == 0.25) return 'கால் கிலோ';
    if (w == 0.5) return 'அரை கிலோ';
    if (w == 0.75) return 'முக்கால் கிலோ';
    if (w == 1.0) return 'ஒரு கிலோ';
    if (w == 2.0) return 'ரெண்டு கிலோ';
    if (w == 3.0) return 'மூணு கிலோ';
    if (w == 4.0) return 'நாலு கிலோ';
    if (w == 5.0) return 'அஞ்சு கிலோ';
    if (w == 6.0) return 'ஆறு கிலோ';
    if (w == w.toInt()) return '${w.toInt()} கிலோ';
    return '${w.toStringAsFixed(2)} கிலோ';
  }

  String _formatPriceDisplay(double w, int totPrice) {
    double perKg = totPrice / w;
    String perKgStr = perKg == perKg.toInt()
        ? perKg.toInt().toString()
        : perKg.toStringAsFixed(2);
    return '₹$perKgStr / ஒரு கிலோ';
  }

  void _startListening() async {
    bool available = await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() {
              _isListening = false;
            });
          }
        }
      },
      onError: (errorNotification) {
        if (mounted) {
          setState(() {
            _isListening = false;
          });
        }
      },
    );

    if (available) {
      if (mounted) {
        setState(() {
          _isListening = true;
        });
      }
      _speechToText.listen(
        onResult: (result) {
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _processVoiceCommand(result.recognizedWords);
          }
        },
        localeId: 'ta_IN',
        listenFor: const Duration(seconds: 10),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('மைக்ரோஃபோன் கிடைக்கவில்லை')),
        );
      }
    }
  }

  void _stopListening() async {
    await _speechToText.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  void _processVoiceCommand(String command) {
    if (command.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('சரியாக பேசவும்')));
      return;
    }

    String productName = "";
    double weight = 1.0;
    int totalPrice = 0;

    final weightRegExp = RegExp(
      r'(கால்|அரை|முக்கால்|ஒரு|ஒன்று|ஒன்னு|ரெண்டு|இரண்டு|மூணு|மூன்று|மூன்|நாலு|நான்கு|அஞ்சு|ஐந்து|ஆறு|1|2|3|4|5|6)\s*(கிலோ|kg|kilo|kilos)',
      caseSensitive: false,
    );
    final weightMatch = weightRegExp.firstMatch(command);

    String textWithoutWeight = command;

    if (weightMatch != null) {
      final weightStr = weightMatch.group(1)!;
      if (weightStr == 'கால்')
        weight = 0.25;
      else if (weightStr == 'அரை')
        weight = 0.5;
      else if (weightStr == 'முக்கால்')
        weight = 0.75;
      else if (weightStr == 'ஒரு' ||
          weightStr == 'ஒன்று' ||
          weightStr == 'ஒன்னு' ||
          weightStr == '1')
        weight = 1.0;
      else if (weightStr == 'ரெண்டு' ||
          weightStr == 'இரண்டு' ||
          weightStr == '2')
        weight = 2.0;
      else if (weightStr == 'மூணு' ||
          weightStr == 'மூன்று' ||
          weightStr == 'மூன்' ||
          weightStr == '3')
        weight = 3.0;
      else if (weightStr == 'நாலு' || weightStr == 'நான்கு' || weightStr == '4')
        weight = 4.0;
      else if (weightStr == 'அஞ்சு' || weightStr == 'ஐந்து' || weightStr == '5')
        weight = 5.0;
      else if (weightStr == 'ஆறு' || weightStr == '6')
        weight = 6.0;

      textWithoutWeight = command
          .replaceFirst(weightMatch.group(0)!, '')
          .trim();
    }

    // Now test if price is mentioned directly.
    String parsedPriceText = textWithoutWeight;
    final tamilNumbers = {
      'இருபத்தி ஐந்து': '25',
      'இருபத்தி அஞ்சு': '25',
      'முப்பத்தி ஐந்து': '35',
      'முப்பத்தி அஞ்சு': '35',
      'பதினைந்து': '15',
      'பதினஞ்சு': '15',
      'தொண்ணூறு': '90',
      'தொன்னூறு': '90',
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
      'ஒம்பது': '9',
      'rupees': '',
      'rupee': '',
      'rs': '',
      'ரூபாய்': '',
      'ரூபா': '',
    };

    // To prevent issues, lower case english terms.
    parsedPriceText = parsedPriceText.toLowerCase();

    for (final key in tamilNumbers.keys) {
      if (parsedPriceText.contains(key)) {
        parsedPriceText = parsedPriceText.replaceAll(
          key,
          tamilNumbers[key]! + ' ',
        );
      }
    }

    final priceRegExp = RegExp(r'\d+');
    final priceMatches = priceRegExp.allMatches(parsedPriceText);

    if (priceMatches.isNotEmpty) {
      // Get the LAST matched number as price. So "Tomatoes 1 kg 50 rs" gives 50.
      final totalPriceStr = priceMatches.last.group(0)!;
      totalPrice = int.tryParse(totalPriceStr) ?? 0;

      productName = textWithoutWeight;
      for (final key in tamilNumbers.keys) {
        productName = productName.replaceAll(key, '');
      }
      productName = productName
          .replaceAll(totalPriceStr, '')
          .replaceAll('ரூபாய்', '')
          .replaceAll('ரூபா', '')
          .replaceAll('Rs', '')
          .replaceAll('rs', '')
          .replaceAll('rupees', '')
          .replaceAll('rupee', '')
          .replaceAll(RegExp(r'\d+'), '')
          .trim();
    } else {
      // Failed to find price
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('விலை புரியவில்லை ()')));
      return;
    }

    if (productName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('பொருள் புரியவில்லை ()')));
      return;
    }

    double perKgPrice = totalPrice / weight;
    String perKgStr = (perKgPrice == perKgPrice.toInt())
        ? perKgPrice.toInt().toString()
        : perKgPrice.toStringAsFixed(2);

    _addNewProduct({
      'name': productName,
      'weight': weight.toString(),
      'per_kg_price': perKgStr,
      'total_price': totalPrice.toString(),
      'price': _formatPriceDisplay(weight, totalPrice),
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(' சேர்க்கப்பட்டது')));
  }

  void _showAddProductDialog() {
    String name = '';
    double _selectedWeight = 1.0;
    String priceStr = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('பொருளை சேர்க்க (Add Product)'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'பொருள் பெயர் (Name)',
                      ),
                      onChanged: (v) => name = v,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<double>(
                      value: _selectedWeight,
                      decoration: const InputDecoration(
                        labelText: 'அளவு (Weight)',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 0.25,
                          child: Text('கால் கிலோ (0.25)'),
                        ),
                        DropdownMenuItem(
                          value: 0.5,
                          child: Text('அரை கிலோ (0.5)'),
                        ),
                        DropdownMenuItem(
                          value: 0.75,
                          child: Text('முக்கால் கிலோ (0.75)'),
                        ),
                        DropdownMenuItem(value: 1.0, child: Text('1 கிலோ')),
                        DropdownMenuItem(value: 2.0, child: Text('2 கிலோ')),
                        DropdownMenuItem(value: 3.0, child: Text('3 கிலோ')),
                        DropdownMenuItem(value: 4.0, child: Text('4 கிலோ')),
                        DropdownMenuItem(value: 5.0, child: Text('5 கிலோ')),
                        DropdownMenuItem(value: 10.0, child: Text('10 கிலோ')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setStateDialog(() => _selectedWeight = v);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'மொத்த விலை (Total Price ₹)',
                      ),
                      onChanged: (v) => priceStr = v,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ரத்து'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final int totalPrice = int.tryParse(priceStr) ?? 0;
                    if (name.isNotEmpty && totalPrice > 0) {
                      double perKgPrice = totalPrice / _selectedWeight;
                      String perKgStr = (perKgPrice == perKgPrice.toInt())
                          ? perKgPrice.toInt().toString()
                          : perKgPrice.toStringAsFixed(2);

                      String displayPrice = _formatPriceDisplay(
                        _selectedWeight,
                        totalPrice,
                      );

                      _addNewProduct({
                        'name': name,
                        'weight': _selectedWeight.toString(),
                        'per_kg_price': perKgStr,
                        'total_price': totalPrice.toString(),
                        'price': displayPrice,
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('சேர்க்க'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: AppBar(
        title: const Text('விற்பனையாளர் பகுதி'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'எனது பொருட்கள்',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: demoProducts.isEmpty
                  ? const Center(
                      child: Text(
                        'பொருட்கள் இல்லை. புதிதாக சேர்க்கவும்.',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      itemCount: demoProducts.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final product = demoProducts[index];
                        return Card(
                          color: Colors.white,
                          child: ListTile(
                            leading: const Icon(
                              Icons.inventory_2,
                              color: Color(0xFF4CAF50),
                            ),
                            title: Text(
                              product['name']!,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  product['price']!,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    final productId =
                                        demoProducts[index]['id'] ?? '';
                                    _deleteProduct(index, productId);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 58,
                    child: ElevatedButton.icon(
                      onPressed: _showAddProductDialog,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text(
                        'சேர்க்க',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 58,
                    child: ElevatedButton.icon(
                      onPressed: _isListening
                          ? _stopListening
                          : _startListening,
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        size: 20,
                      ),
                      label: Text(
                        _isListening ? 'கேட்கிறது' : 'பேசவும்',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: _isListening
                            ? Colors.red
                            : const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 58,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) => const SellerOrdersScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.inventory_2, size: 18),
                      label: const Text(
                        'விற்பனை',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'குரல் மூலம் சேர்க்க: "மைக்" பொத்தானை அழுத்தி "ஆரஞ்சு 2 கிலோ 50 ரூபாய்" என்று கூறவும்.',
                      style: TextStyle(fontSize: 14, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    final url = '${ApiService.baseUrl}/orders';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _orders = data['orders'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _exportCSV() async {
    try {
      final List<String> rows = [
        'பொருள் பெயர்,அளவு,ஒரு கிலோ விலை,மொத்தம்,வாங்கியவர்',
      ];
      for (var order in _orders) {
        final name = order['product_name'] ?? '';
        final qty = order['quantity'] ?? '';
        final pkg = order['per_kg_price'] ?? '';
        final tot = order['total_price'] ?? '';
        final buyer = order['buyer_name'] ?? 'தெரியவில்லை';
        rows.add('$name,$qty,$pkg,$tot,$buyer');
      }
      String csv = rows.join('\n');

      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/sales_report.csv';
      final file = File(path);
      await file.writeAsString('\uFEFF' + csv);

      await Share.shareXFiles([XFile(path)], text: 'Sales Report');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV ஏற்றுமதி செய்ய முடியவில்லை: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: AppBar(
        title: const Text('விற்பனைகள்'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _orders.isEmpty
                      ? const Center(
                          child: Text(
                            'இன்னும் விற்பனைகள் இல்லை',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _orders.length,
                          itemBuilder: (context, index) {
                            final order = _orders[index];
                            final statusColor = order['status'] == 'முடிந்தது'
                                ? Colors.green
                                : Colors.orange;

                            return Card(
                              color: Colors.white,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order['product_name'] ?? 'தெரியவில்லை',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'அளவு: ${order['quantity'] ?? ''} கிலோ',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'ஒரு கிலோ விலை: ₹${order['per_kg_price'] ?? ''}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'மொத்தம்: ₹${order['total_price'] ?? ''}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2E7D32),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'வாங்கியவர்: ${order['buyer_name'] ?? 'தெரியவில்லை'}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Text(
                                          'நிலை: ',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                        Text(
                                          order['status'] ?? 'நிலுவையில்',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (_orders.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.black12)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'மொத்த விற்பனை:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '₹',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _exportCSV,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.download),
                            label: const Text(
                              'அறிக்கை ஏற்றுமதி (CSV)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
