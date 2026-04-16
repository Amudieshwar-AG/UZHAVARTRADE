class BuyerDiscovery extends StatefulWidget {
  const BuyerDiscovery({super.key});

  @override
  State<BuyerDiscovery> createState() => _BuyerDiscoveryState();
}

class _BuyerDiscoveryState extends State<BuyerDiscovery> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isListening = false;
  String _searchQuery = "";

  void _listen() async {
    if (!_isListening) {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) return;

      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        await TamilTts.speak(_tts, "என்ன வேணும்? பேசுங்கள்");

        _speech.listen(
          onResult: (val) {
            setState(() {
              _searchQuery = val.recognizedWords;
            });
            if (val.finalResult) {
              _handleSearch(_searchQuery);
            }
          },
          localeId: 'ta_IN',
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _handleSearch(String query) async {
    if (query.isEmpty) return;

    var box = Hive.box('products');
    int count = 0;
    for (var i = 0; i < box.length; i++) {
      var p = box.getAt(i);
      if (query.contains(p['name'].split(' ')[0])) {
        count++;
      }
    }

    if (count > 0) {
      await TamilTts.speak(_tts, "$count பொருட்கள் கிடைக்கின்றன");
    } else {
      await TamilTts.speak(_tts, "மன்னிக்கவும், இப்போது கிடைக்கவில்லை");
    }

    setState(() {
      _isListening = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    var box = Hive.box('products');

    return Scaffold(
      appBar: AppBar(title: const Text('வாங்கும் பக்கம்')),
      body: Column(
        children: [
          const SizedBox(height: 40),
          GestureDetector(
            onTap: _listen,
            child:
                CircleAvatar(
                      radius: 60,
                      backgroundColor: _isListening
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                      child: const Icon(
                        Icons.mic,
                        size: 60,
                        color: Colors.white,
                      ),
                    )
                    .animate(target: _isListening ? 1 : 0)
                    .scale(end: const Offset(1.2, 1.2)),
          ),
          const SizedBox(height: 20),
          Text(
            "தட்டி பேசுங்கள்:",
            style: GoogleFonts.notoSansTamil(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '"காய்கறி காட்டு"',
            style: GoogleFonts.notoSansTamil(fontSize: 16),
          ),
          const SizedBox(height: 20),
          if (_searchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "தேடல்: $_searchQuery",
                style: GoogleFonts.notoSansTamil(fontSize: 18),
              ),
            ),
          const SizedBox(height: 10),
          const Divider(),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box products, _) {
                var filtered = products.values
                    .where(
                      (p) =>
                          _searchQuery.isEmpty ||
                          p['name'].toString().contains(
                            _searchQuery.split(' ')[0],
                          ),
                    )
                    .toList();

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    var prod = filtered[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.shopping_basket_outlined,
                          size: 30,
                        ),
                        title: Text(
                          prod['name'],
                          style: GoogleFonts.notoSansTamil(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          "₹${prod['price']}",
                          style: GoogleFonts.notoSansTamil(fontSize: 18),
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.call),
                          label: const Text("தொடர்பு கொள்"),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
