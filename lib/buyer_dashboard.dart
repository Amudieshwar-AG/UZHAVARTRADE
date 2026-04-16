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
    return demoProducts.where((p) => (p['name'] ?? 'à¤§à¤•à¤¯à¤¾à‡à¤²à¥à¤²à¤¾').toLowerCase().contains(_searchQuery.toLowerCase())).toList();
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
          "product_name": product['name'] ?? "à¤§à¤•à¤¯à¤¾à‡à¤²à¥à¤²à¤¾",
          "quantity": quantity.toString(),
          "total_price": totalPrice.toStringAsFixed(2),
        }),
      );
      
      if (!mounted) return;
      Navigator.pop(context); // Close loader

      if (response.statusCode == 201) {
        await _flutterTts.speak("à¤…à¤¾à¤²à¥à¤Ÿà¤²à¥ à¤µà¥‡à¤±à¥à¤°à¤¿");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('à¤¥à¤¾à¤°à¥à¤Ÿà¤°à¥ à¥…à¥‡à¤°à¥à¤°à¥¿'!, style: TextStyle(fontSize: 18)),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('à¤¥à¤¾à¤°à¥à¤Ÿà¤°à¥ à¤¤à¥‡à¤¾à¤²à¥à¤µà¤¿', style: TextStyle(fontSize: 18))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(NackBar(content: Text()à¤ªà¤¿à¤¸à¥ˆ: $e')));
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
              title: Text(product['name'] ?? "à¤§à¤•à¤¯à¤¾à‡à¤²à¥à¤²à¤¾", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text()à¤…à¤±à¤µà¥ˆ à¤¥à¥à¤¦à¥·à¤°à¥à¤¨à¥à¤¥à¥†à¤Ÿà¤®à¥à¤•à¤µà¤®à¥', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('à¤•à¤¾à¤²à¥ à¤•à¤¿à¤²à¥ˆ (0.25)', style: TextStyle(fontSize: 16)),
                        selected: selectedQuantity == 0.25,
                        onSelected: (val) {
                          if (val) setStateDialog(() => selectedQuantity = 0.25);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('à¤…à¤°à¥ˆ à¤•à¤¿à¤²à¥ˆ (0.5)', style: TextStyle(fontSize: 16)),
                        selected: selectedQuantity == 0.5,
                        onSelected: (val) {
                          if (val) setStateDialog(() => selectedQuantity = 0.5);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('à¤·à¤°à¥ à¤•à¤¿à¤²à¥ˆ (1.0)', style: TextStyle(fontSize: 16)),
                        selected: selectedQuantity == 1.0,
                        onSelected: (val) {
                          if (val) setStateDialog() => selectedQuantity = 1.0);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'à¤®à¥Šà¤¥à¥à¤¥ à¤µà¤¿à¤²à¥†: â‚¹${(perKgPrice * selectedQuantity).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 10),
                  const Text('à¤‡à¤¨à¥à¤¥ à¤ªà¤©à¤°à¥à¤²à¥† à¤µ`¤¾à¤•à¥à¤• à¤µà¤¿à¤°à¥ à¤®à¥à¤°à¤¿à¤²à¥Œà¤¥à¥‡à¤°à¥à¤•à¤²à¥žà¥‡à¤²?', style: TextStyle(fontSize: 16)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('à¤…à¤²à¥à¤²à¥†', style: TextStyle(fontSize: 18)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    _processPurchase(product, selectedQuantity, perKcPrice * selectedQuantity);
                  },
                  child: const Text('à¤·à¤¾à¤Çà¤•à¤±÷, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('â¤®à¥‰à¤•à¥à¤°à¥»à¥à¤³à¥¿à¥à¤§à¤·à¥† à¤ªà¤¿à¤µà¥ˆ', style: TextStyle(fontSize: 18))));
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          localeId: 'ta_IN',
          onResult: (result) {
            setState(() {
              String words = result.recognizedWords;
              String query = words.replaceAll()à¤•à¤¾à¤¯à¥à¤•à¤·', '').replaceAll((à¤µà¥‡à¤£à¥à¤Ÿà¥o', '').trim();
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
        title: const Text('à¤µÙ€à¤¾à¤£à¥à¤•à¥à¤¨à¤µà¤°à¥ à¤ªà¤•à¥`¤¤à¤¿', style: TextStyle(fontWeight: FontWeight.bold)),        
        backgroundColor: const Color(0xFÌÐÁÔÀ¤°(€€€€€€€™½É•É½Õ¹‘½±½Èè½±½ÉÌ¹Ý¡¥Ñ”°(€€€€€€€…Ñ¥½¹Ìèl(€€€€€€€€€¥˜€¡}Í•…É¡EÕ•Éä¹¥Í9½ÑµÁÑä¤(€€€€€€€€€€€%½¹	ÕÑÑ½¸ (€€€€€€€€€€€€€¥½¸è½¹ÍÐ%½¸¡%½¹Ì¹±•…È¤°(€€€€€€€€€€€€€½¹AÉ•ÍÍ•è€ ¤€ôøÍ•ÑMÑ…Ñ”  ¤€ôø}Í•…É¡EÕ•Éä€ô€œœ¤°(€€€€€€€€€€€€¤(€€€€€€€t°(€€€€€€¤°(€€€€€‰½‘äè½±Õµ¸ (€€€€€€€¡¥±‘É•¸èl(€€€€€€€€€áÁ…¹‘• (€€€€€€€€€€€¡¥±èÁÉ½‘ÕÑÌ¹¥ÍµÁÑä(€€€€€€€€€€€€€€€€ü½¹ÍÐ•¹Ñ•È (€€€€€€€€€€€€€€€€€€€€€¡¥±èQ•áÐ (€€€€€€€€€€€€€€€€€€€€€€€€Ÿ‚’Ÿ‚’W‚’¿‚’û‚‚’Ë‚–7‚’Ë‚’øœ°(€€€€€€€€€€€€€€€€€€€€€€€ÍÑå±”èQ•áÑMÑå±”¡™½¹ÑM¥é”è€ÈÈ°½±½Èè½±½ÉÌ¹É•ä°™½¹Ñ]•¥¡Ðè½¹Ñ]•¥¡Ð¹‰½±¤°€(€€€€€€€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€€€€€€€€€¤(€€€€€€€€€€€€€€€€è1¥ÍÑY¥•Ü¹Í•Á…É…Ñ• (€€€€€€€€€€€€€€€€€€€Á…‘‘¥¹œè½¹ÍÐ‘•%¹Í•ÑÌ¹…±° ÄÈ¤°(€€€€€€€€€€€€€€€€€€€¥Ñ•µ½Õ¹ÐèÁÉ½‘ÕÑÌ¹±•¹Ñ °(€€€€€€€€€€€€€€€€€€€Í•Á…É…Ñ½É	Õ¥±‘•Èè€¡½¹Ñ•áÐ°¥¹‘•à¤€ôø½¹ÍÐM¥é•‘	½à¡¡•¥¡Ðè€à¤°(€€€€€€€€€€€€€€€€€€€¥Ñ•µ	Õ¥±‘•Èè€¡½¹Ñ•áÐ°¥¹‘•à¤ì(€€€€€€€€€€€€€€€€€€€€€™¥¹…°ÁÉ½‘ÕÐ€ôÁÉ½‘ÕÑÍm¥¹‘•átì(€€€€€€€€€€€€€€€€€€€€€MÑÉ¥¹œ‘¥ÍÁ±…åAÉ¥”€ôÁÉ½‘ÕÑl±•É}­}ÁÉ¥”t€„ô¹Õ±°€˜˜ÁÉ½‘ÕÑlÁ•É}­}ÁÉ¥”t„¹¥Í9½ÑµÁÑä€(€€€€€€€€€€€€€€€€€€€€€€€€€€ü€ŸŠ
ä‘íÁÉ½‘ÕÑl±•É}­}ÁÉ¥”uô€¼ƒ‚’«‚’Ã‚–ƒ‚’W‚’ÿ‚’Ë‚– œ€(€€€€€€€€€€€€€€€€€€€€€€€€€€è€ŸŠ
ä‘íÁÉ½‘ÕÑlÑ½Ñ…±}ÁÉ¥”uô€¼ƒ‚’«‚’Ã‚–ƒ‚’W‚’ÿ‚’Ë‚–$œì((€€€€€€€€€€€€€€€€€€€€€É•ÑÕÉ¸…É (€€€€€€€€€€€€€€€€€€€€€€€•±•Ù…Ñ¥½¸è€È°(€€€€€€€€€€€€€€€€€€€€€€€Í¡…Á”èI½Õ¹‘•‘I•Ñ…¹±•	½É‘•È¡‰½É‘•ÉI…‘¥ÕÌè	½É‘•ÉI…‘¥ÕÌ¹¥ÉÕ±…È ÄÈ¤¤°(€€€€€€€€€€€€€€€€€€€€€€€½±½Èè½±½ÉÌ¹Ý¡¥Ñ”°(€€€€€€€€€€€€€€€€€€€€€€€¡¥±èA…‘‘¥¹œ (€€€€€€€€€€€€€€€€€€€€€€€€€Á…‘‘¥¹œè½¹ÍÐ‘•%¹Í•ÑÌ¹Íåµµ•ÑÉ¥Œ¡Ù•ÉÑ¥…°è€à¸À¤°(€€€€€€€€€€€€€€€€€€€€€€€€€¡¥±è1¥ÍÑQ¥±” (€€€€€€€€€€€€€€€€€€€€€€€€€€€Ñ¥Ñ±”èQ•áÐ (€€€€€€€€€€€€€€€€€€€€€€€€€€€€€ÁÉ½‘ÕÑl¹…µ”t€üü€‹‚’Ÿ‚’W‚’¿‚’û‚‚’Ë‚–7‚’Ë‚’øˆ°(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€ÍÑå±”è½¹ÍÐQ•áÑMÑå±”¡™½¹ÑM¥é”è€ÈÈ°™½¹Ñ]•¥¡Ðè½¹Ñ]•¥¡Ð¹ÜØÀÀ¤°(€€€€€€€€€€€€€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€€€€€€€€€€€€€€€€ÍÕ‰Ñ¥Ñ±”èA…‘‘¥¹œ (€€€€€€€€€€€€€€€€€€€€€€€€€€€€€Á…‘‘¥¹œè½¹ÍÐ‘•%¹Í•ÑÌ¹½¹±ä¡Ñ½Àè€Ð¸À¤°(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€¡¥±èQ•áÐ (€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€‘¥ÍÁ±…åAÉ¥”°€(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€ÍÑå±”è½¹ÍÐQ•áÑMÑå±”¡½±½Èè½±½È ÁáÉÝÌÈ¤°™½¹Ñ]•¥¡Ðè½¹Ñ]•¥¡Ð¹‰½±°™½¹ÑM¥é”è€Äà¤(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€€€€€€€€€€€€€€€€ÑÉ…¥±¥¹œè±•Ù…Ñ•‘	ÕÑÑ½¸ (€€€€€€€€€€€€€€€€€€€€€€€€€€€€€ÍÑå±”è±•Ù…Ñ•‘	ÕÑÑ½¸¹ÍÑå±•É½´ (€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€Á…‘‘¥¹œè½¹ÍÐ‘•%¹Í•ÑÌ¹Íåµµ•ÑÉ¥Œ¡¡½É¥é½¹Ñ…°è€ÈÀ°Ù•ÉÑ¥…°è€ÄÈ¤°(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€‰…­É½Õ¹‘½±½Èè½¹ÍÐ½±½È ÁáÑÔÀ¤°(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€™½É•É½Õ¹‘½±½Èè½±½ÉÌ¹Ý¡¥Ñ”°(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€Í¡…Á”èI½Õ¹‘•‘I•Ñ…¹±•	½É‘•È¡‰½É‘•ÉI…‘¥ÕÌè	½É‘•ÉI…‘¥ÕÌ¹¥ÉÕ±…È à¤¤(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€½¹AÉ•ÍÍ•è€ ¤€ôø}Í¡½ÝEÕ…¹Ñ¥Ñå¥…±½œ¡ÁÉ½‘ÕÐ¤°€€€€(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€¡¥±è½¹ÍÐQ•áÐ Ÿ‚’ß‚’û‚’‚’W‚’ÇÜ°ÍÑå±”èQ•áÑMÑå±”¡™½¹ÑM¥é”è€Äà°™½¹Ñ]•¥¡Ðè½¹Ñ]•¥¡Ð¹‰½±¤¤°(€€€€€€€€€€€€€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€€€€€€€€€€€¤ì(€€€€€€€€€€€€€€€€€€€ô°(€€€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€¤°(€€€€€€€€€½¹Ñ…¥¹•È (€€€€€€€€€€€Á…‘‘¥¹œè½¹ÍÐ‘•%¹Í•ÑÌ¹…±° ÄØ¤°(€€€€€€€€€€€‘•½É…Ñ¥½¸è	½á•½É…Ñ¥½¸ (€€€€€€€€€€€€€½±½Èè½±½ÉÌ¹Ý¡¥Ñ”°(€€€€€€€€€€€€€‰½áM¡…‘½Üèl(€€€€€€€€€€€€€€€	½áM¡…‘½Ü (€€€€€€€€€€€€€€€€€½±½Èè½±½ÉÌ¹‰±…¬¹Ý¥Ñ¡=Á…¥Ñä À¸ÀÔ¤°(€€€€€€€€€€€€€€€€€‰±ÕÉI…‘¥ÕÌè€ÄÀ°(€€€€€€€€€€€€€€€€€½™™Í•Ðè½¹ÍÐ=™™Í•Ð À°€´Ô¤°(€€€€€€€€€€€€€€€€¤(€€€€€€€€€€€€€t(€€€€€€€€€€€€¤°(€€€€€€€€€€€¡¥±èM¥é•‘	½à (€€€€€€€€€€€€€Ý¥‘Ñ è‘½Õ‰±”¹¥¹™¥¹¥Ñä°(€€€€€€€€€€€€€¡•¥¡Ðè€ØÀ°(€€€€€€€€€€€€€¡¥±è±•Ù…Ñ•‘	ÕÑÑ½¸¹¥½¸ (€€€€€€€€€€€€€€€ÍÑå±”è±•Ù…Ñ•‘	ÕÑÑ½¸¹ÍÑå±•É½´ (€€€€€€€€€€€€€€€€€‰…­É½Õ¹‘½±½Èè}¥Í1¥ÍÑ•¹¥¹œ€ü½±½ÉÌ¹É•€è½±½ÉÌ¹‰±Õ”°(€€€€€€€€€€€€€€€€€™½É•É½Õ¹‘½±½Èè½±½ÉÌ¹Ý¡¥Ñ”°(€€€€€€€€€€€€€€€€€Í¡…Á”èI½Õ¹‘•‘I•Ñ…¹±•	½É‘•È¡‰½É‘•ÉI…‘¥ÕÌè	½É‘•ÉI…‘¥ÕÌ¹¥ÉÕ±…È ÄÈ¤¤(€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€€€€¥½¸è%½¸¡}¥Í1¥ÍÑ•¹¥¹œ€ü%½¹Ì¹µ¥Œ€è%½¹Ì¹µ¥}¹½¹”°Í¥é”è€Èà¤°(€€€€€€€€€€€€€€€±…‰•°èQ•áÐ (€€€€€€€€€€€€€€€€€}¥Í1¥ÍÑ•¹¥¹œ€ü€Ÿ‚’W¦‚’—‚–7‚’W‚–3‚’Ã‚’ø¸¸¸œ€è€ŸÂ~:ƒ‚’«‚–‚’«‚’×‚–‚’°œ°(€€€€€€€€€€€€€€€€€ÍÑå±”è½¹ÍÐQ•áÑMÑå±”¡™½¹ÑM¥é”è€ÈÈ°™½¹Ñ]•¥¡Ðè½¹Ñ]•¥¡Ð¹‰½±¤°(€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€€€€½¹AÉ•ÍÍ•è}±¥ÍÑ•¸°(€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€¤°(€€€€€€€€€€¤(€€€€€€€t°(€€€€€€¤°(€€€€¤ì(€ô)ô