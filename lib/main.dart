// ==============================================================================
// POCKET SPLITTER - Production-Ready Mobile Bill-Splitting & Meme Invoice App
// Framework: Flutter 3.x (Dart 3.x)
// State Management: StatefulWidget & ValueNotifier
// File: lib/main.dart
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PocketSplitterApp());
}

// ------------------------------------------------------------------------------
// MODELS
// ------------------------------------------------------------------------------

class Participant {
  final String id;
  final String name;
  final String avatar;
  final Color color;

  Participant({
    required this.id,
    required this.name,
    required this.avatar,
    required this.color,
  });
}

class BillItem {
  final String id;
  String name;
  double price;
  int quantity;
  List<String> participantIds;

  BillItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
    required this.participantIds,
  });

  double get totalPrice => price * quantity;
}

enum SplitMode { proportional, equal }

class BillSettings {
  String title;
  DateTime date;
  String currency;
  double taxPercent;
  double servicePercent;
  double discountAmount;
  SplitMode splitMode;
  int roundTo;

  BillSettings({
    this.title = 'Nongkrong Santai',
    DateTime? date,
    this.currency = 'Rp',
    this.taxPercent = 10.0,
    this.servicePercent = 5.0,
    this.discountAmount = 0.0,
    this.splitMode = SplitMode.proportional,
    this.roundTo = 100,
  }) : date = date ?? DateTime.now();
}

class PaymentInfo {
  String provider;
  String accountNumber;
  String accountName;

  PaymentInfo({
    this.provider = 'BCA',
    this.accountNumber = '1234567890',
    this.accountName = 'Bendahara Nongkrong',
  });
}

class PersonItemShare {
  final String itemName;
  final double amount;
  final int quantity;
  final int splitAmong;

  PersonItemShare({
    required this.itemName,
    required this.amount,
    required this.quantity,
    required this.splitAmong,
  });
}

class PersonBreakdown {
  final Participant participant;
  final List<PersonItemShare> shares;
  final double subtotal;
  final double tax;
  final double service;
  final double discount;
  final double total;
  bool isPaid;

  PersonBreakdown({
    required this.participant,
    required this.shares,
    required this.subtotal,
    required this.tax,
    required this.service,
    required this.discount,
    required this.total,
    this.isPaid = false,
  });
}

// ------------------------------------------------------------------------------
// APP ENTRY POINT & THEME
// ------------------------------------------------------------------------------

class PocketSplitterApp extends StatefulWidget {
  const PocketSplitterApp({super.key});

  @override
  State<PocketSplitterApp> createState() => _PocketSplitterAppState();
}

class _PocketSplitterAppState extends State<PocketSplitterApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pocket Splitter',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFF97316), // Fun Vibrant Coral / Orange
        brightness: Brightness.light,
        fontFamily: 'Roboto',
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFF97316),
        brightness: Brightness.dark,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade800),
          ),
        ),
      ),
      home: MainScreen(
          onToggleTheme: toggleTheme, isDarkMode: _themeMode == ThemeMode.dark),
    );
  }
}

// ------------------------------------------------------------------------------
// MAIN SCREEN WITH BOTTOM NAVIGATION
// ------------------------------------------------------------------------------

class MainScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const MainScreen(
      {super.key, required this.onToggleTheme, required this.isDarkMode});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentTabIndex = 0;

  // App State
  late List<Participant> _participants;
  late List<BillItem> _items;
  late BillSettings _settings;
  late PaymentInfo _payment;
  final Map<String, bool> _paidStatus = {};

  @override
  void initState() {
    super.initState();
    _settings = BillSettings(
      title: 'Kopi & Dimsum Friday',
      currency: 'Rp',
      taxPercent: 10,
      servicePercent: 5,
      splitMode: SplitMode.proportional,
    );

    _payment = PaymentInfo(
      provider: 'BCA / QRIS',
      accountNumber: '8830192831',
      accountName: 'Andi Pratama',
    );

    _participants = [
      Participant(id: '1', name: 'Alex', avatar: '😎', color: Colors.blue),
      Participant(id: '2', name: 'Maya', avatar: '🌸', color: Colors.pink),
      Participant(id: '3', name: 'Kevin', avatar: '🍕', color: Colors.amber),
      Participant(id: '4', name: 'Sarah', avatar: '✨', color: Colors.purple),
    ];

    _items = [
      BillItem(
        id: '101',
        name: 'Dimsum Hakau Platter',
        price: 78000,
        quantity: 2,
        participantIds: ['1', '2', '3', '4'],
      ),
      BillItem(
        id: '102',
        name: 'Mie Karet Ayam Jamur',
        price: 45000,
        quantity: 1,
        participantIds: ['1'],
      ),
      BillItem(
        id: '103',
        name: 'Matcha Oat Latte',
        price: 38000,
        quantity: 1,
        participantIds: ['2'],
      ),
      BillItem(
        id: '104',
        name: 'Crispy Enoki & Fries',
        price: 32000,
        quantity: 1,
        participantIds: ['3', '4'],
      ),
    ];
  }

  // Calculation Engine
  List<PersonBreakdown> get breakdowns {
    double subtotal = 0;
    final Map<String, List<PersonItemShare>> sharesMap = {};
    for (var p in _participants) {
      sharesMap[p.id] = [];
    }

    for (var item in _items) {
      final total = item.totalPrice;
      subtotal += total;
      if (item.participantIds.isNotEmpty) {
        final sharePrice = total / item.participantIds.length;
        for (var pid in item.participantIds) {
          sharesMap[pid]?.add(PersonItemShare(
            itemName: item.name,
            amount: sharePrice,
            quantity: item.quantity,
            splitAmong: item.participantIds.length,
          ));
        }
      }
    }

    final netSubtotal = max(0.0, subtotal - _settings.discountAmount);
    final serviceTotal = (netSubtotal * _settings.servicePercent) / 100;
    final taxTotal =
        ((netSubtotal + serviceTotal) * _settings.taxPercent) / 100;

    final activeP = _participants
        .where((p) => (sharesMap[p.id]?.isNotEmpty ?? false))
        .toList();
    final count = activeP.isNotEmpty ? activeP.length : _participants.length;

    return _participants.map((p) {
      final pShares = sharesMap[p.id] ?? [];
      final pSubtotal = pShares.fold(0.0, (acc, s) => acc + s.amount);

      double pTax = 0;
      double pService = 0;
      double pDiscount = 0;

      if (_settings.splitMode == SplitMode.proportional) {
        final ratio = subtotal > 0 ? (pSubtotal / subtotal) : (1.0 / count);
        pTax = taxTotal * ratio;
        pService = serviceTotal * ratio;
        pDiscount = _settings.discountAmount * ratio;
      } else {
        if (pShares.isNotEmpty) {
          pTax = taxTotal / count;
          pService = serviceTotal / count;
          pDiscount = _settings.discountAmount / count;
        }
      }

      double finalTotal = max(0.0, pSubtotal - pDiscount + pTax + pService);
      if (_settings.roundTo > 0) {
        finalTotal = (finalTotal / _settings.roundTo).ceil() *
            _settings.roundTo.toDouble();
      }

      return PersonBreakdown(
        participant: p,
        shares: pShares,
        subtotal: pSubtotal,
        tax: pTax,
        service: pService,
        discount: pDiscount,
        total: finalTotal,
        isPaid: _paidStatus[p.id] ?? false,
      );
    }).toList();
  }

  String formatMoney(double val) {
    return '${_settings.currency} ${val.toInt().toString().replaceAllMapped(RegExp(r'(\\d{1,3})(?=(\\d{3})+(?!\\d))'), (Match m) => '${m[1]}.')}';
  }

  void _showAddParticipantDialog() {
    final textController = TextEditingController();
    String selectedEmoji = '🐱';
    final emojis = ['😎', '🌸', '🍕', '🐱', '🚀', '☕', '🥑', '🔥'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Add Friend',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Friend's name",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Choose Avatar:')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: emojis.map((e) {
                  final isSelected = selectedEmoji == e;
                  return ChoiceChip(
                    label: Text(e, style: const TextStyle(fontSize: 20)),
                    selected: isSelected,
                    onSelected: (val) {
                      setDialogState(() => selectedEmoji = e);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                if (textController.text.trim().isNotEmpty) {
                  setState(() {
                    _participants.add(Participant(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: textController.text.trim(),
                      avatar: selectedEmoji,
                      color: Colors
                          .primaries[Random().nextInt(Colors.primaries.length)],
                    ));
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    int qty = 1;
    final List<String> selectedPids = List.from(_participants.map((p) => p.id));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Add Bill Item',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Item Name',
                    hintText: 'e.g. Iced Vanilla Latte',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Price',
                          hintText: '35000',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Container(
                        height: 58,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              onPressed: qty > 1
                                  ? () => setDialogState(() => qty--)
                                  : null,
                            ),
                            Text('$qty',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              onPressed: () => setDialogState(() => qty++),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Split between:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _participants.map((p) {
                    final isChecked = selectedPids.contains(p.id);
                    return FilterChip(
                      avatar: Text(p.avatar),
                      label: Text(p.name),
                      selected: isChecked,
                      onSelected: (val) {
                        setDialogState(() {
                          if (val) {
                            selectedPids.add(p.id);
                          } else {
                            if (selectedPids.length > 1) {
                              selectedPids.remove(p.id);
                            }
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                final p = double.tryParse(priceController.text) ?? 0;
                if (nameController.text.trim().isNotEmpty && p > 0) {
                  setState(() {
                    _items.add(BillItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text.trim(),
                      price: p,
                      quantity: qty,
                      participantIds: selectedPids,
                    ));
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add Item'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('🧾', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            const Text('Pocket Splitter',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildBillEditorTab(),
          _buildBreakdownTab(),
          _buildMemeInvoicesTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (idx) => setState(() => _currentTabIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Bill & Items',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Debt Summary',
          ),
          NavigationDestination(
            icon: Icon(Icons.sentiment_very_satisfied_outlined),
            selectedIcon: Icon(Icons.sentiment_very_satisfied),
            label: 'Meme Invoices',
          ),
        ],
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddItemDialog,
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Item',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildBillEditorTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Friends Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Friends & Squad',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: _showAddParticipantDialog,
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Add Friend'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _participants.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) {
              final p = _participants[i];
              return Container(
                width: 76,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(p.avatar, style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 4),
                    Text(
                      p.name,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        // Items List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Items (${_items.length})',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text('Tap item to edit',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
        const SizedBox(height: 8),
        ..._items.map((item) {
          final assignedNames = item.participantIds
              .map((id) => _participants
                  .firstWhere((p) => p.id == id,
                      orElse: () => Participant(
                          id: '', name: '', avatar: '', color: Colors.grey))
                  .name)
              .join(', ');

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Shared by: $assignedNames',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatMoney(item.totalPrice),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  if (item.quantity > 1)
                    Text('${item.quantity}x @ ${formatMoney(item.price)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 16),

        // Tax & Service Settings
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tax, Service & Split Settings',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tax: ${_settings.taxPercent.toInt()}%'),
                          Slider(
                            value: _settings.taxPercent,
                            min: 0,
                            max: 20,
                            divisions: 20,
                            onChanged: (v) =>
                                setState(() => _settings.taxPercent = v),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Service: ${_settings.servicePercent.toInt()}%'),
                          Slider(
                            value: _settings.servicePercent,
                            min: 0,
                            max: 15,
                            divisions: 15,
                            onChanged: (v) =>
                                setState(() => _settings.servicePercent = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SegmentedButton<SplitMode>(
                  segments: const [
                    ButtonSegment(
                        value: SplitMode.proportional,
                        label: Text('Proportional')),
                    ButtonSegment(
                        value: SplitMode.equal, label: Text('Split Evenly')),
                  ],
                  selected: {_settings.splitMode},
                  onSelectionChanged: (val) =>
                      setState(() => _settings.splitMode = val.first),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildBreakdownTab() {
    final list = breakdowns;
    final totalSpent = list.fold(0.0, (acc, b) => acc + b.total);
    final totalCollected =
        list.where((b) => b.isPaid).fold(0.0, (acc, b) => acc + b.total);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Header Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFF97316), Color(0xFFFB923C)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Hangout Bill',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                formatMoney(totalSpent),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: totalSpent > 0 ? (totalCollected / totalSpent) : 0,
                backgroundColor: Colors.white30,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 6),
              Text(
                'Collected: ${formatMoney(totalCollected)} of ${formatMoney(totalSpent)}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const Text('Individual Shares',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        ...list.map((b) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: b.participant.color.withOpacity(0.2),
                          child: Text(b.participant.avatar,
                              style: const TextStyle(fontSize: 20)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.participant.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text(
                                '${b.shares.length} items ordered',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(formatMoney(b.total),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 17)),
                            Text(
                              b.isPaid ? 'PAID' : 'UNPAID',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color:
                                    b.isPaid ? Colors.green : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _paidStatus[b.participant.id] = !b.isPaid;
                            });
                          },
                          icon: Icon(
                              b.isPaid
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: b.isPaid ? Colors.green : Colors.grey),
                          label:
                              Text(b.isPaid ? 'Mark Unpaid' : 'Mark as Paid'),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF97316),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            _openMemeInvoiceSheet(b);
                          },
                          icon: const Icon(Icons.share, size: 16),
                          label: const Text('Meme Invoice'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildMemeInvoicesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Select Friend for Meme Invoice 🎨',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
            'Pick a delinquent bestie to generate a hilarious shareable debt notice:'),
        const SizedBox(height: 16),
        ...breakdowns.map((b) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: b.participant.color.withOpacity(0.2),
                  child: Text(b.participant.avatar,
                      style: const TextStyle(fontSize: 22)),
                ),
                title: Text(b.participant.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Owes: ${formatMoney(b.total)}'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _openMemeInvoiceSheet(b),
                  child: const Text('Generate'),
                ),
              ),
            )),
      ],
    );
  }

  void _openMemeInvoiceSheet(PersonBreakdown b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MemeInvoiceModal(
        breakdown: b,
        settings: _settings,
        payment: _payment,
        formatMoney: formatMoney,
      ),
    );
  }
}

// ------------------------------------------------------------------------------
// MEME INVOICE MODAL WIDGET
// ------------------------------------------------------------------------------

class MemeInvoiceModal extends StatefulWidget {
  final PersonBreakdown breakdown;
  final BillSettings settings;
  final PaymentInfo payment;
  final String Function(double) formatMoney;

  const MemeInvoiceModal({
    super.key,
    required this.breakdown,
    required this.settings,
    required this.payment,
    required this.formatMoney,
  });

  @override
  State<MemeInvoiceModal> createState() => _MemeInvoiceModalState();
}

class _MemeInvoiceModalState extends State<MemeInvoiceModal> {
  String selectedTemplate = 'tilang'; // 'tilang', 'official', 'aesthetic'

  String generateShareText() {
    final b = widget.breakdown;
    final total = widget.formatMoney(b.total);
    final items = b.shares
        .map((s) => '• ${s.itemName}: ${widget.formatMoney(s.amount)}')
        .join('\n');

    if (selectedTemplate == 'tilang') {
      return '''🚨 SURAT BUKTI PELANGGARAN NONGKRONG (TILANG) 🚨
Nama Pelanggar: ${b.participant.name}
Pasal: 378 KUHP (Kitab Undang-Undang Hutang Pertemanan)
Barang Bukti Konsumsi:
$items

💰 TOTAL DENDA: $total
💳 Transfer ke: ${widget.payment.provider} - ${widget.payment.accountNumber} (a/n ${widget.payment.accountName})

⚠️ Batas waktu 1x24 jam sebelum disindir di instastory!''';
    } else {
      return '''Halo bestie ${b.participant.name} 🥰
Patungan ${widget.settings.title} kemarin totalnya $total yaa.
Transfer ke ${widget.payment.provider} ${widget.payment.accountNumber} an ${widget.payment.accountName}. Makasiiih! 🙏''';
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.breakdown;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Meme Invoice Generator',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          // Template Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('🚨 Surat Tilang Nongkrong'),
                  selected: selectedTemplate == 'tilang',
                  onSelected: (val) =>
                      setState(() => selectedTemplate = 'tilang'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('⚖️ Bestie Debt Notice'),
                  selected: selectedTemplate == 'official',
                  onSelected: (val) =>
                      setState(() => selectedTemplate = 'official'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('☕ Minimalist Cafe Receipt'),
                  selected: selectedTemplate == 'aesthetic',
                  onSelected: (val) =>
                      setState(() => selectedTemplate = 'aesthetic'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Receipt Preview
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: selectedTemplate == 'tilang'
                      ? const Color(0xFFFFFBEB)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selectedTemplate == 'tilang'
                        ? Colors.amber.shade400
                        : Colors.grey.shade300,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (selectedTemplate == 'tilang') ...[
                      const Center(
                        child: Text(
                          '🚨 SURAT TILANG NONGKRONG 🚨',
                          style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w900,
                              fontSize: 16),
                        ),
                      ),
                      const Center(
                        child: Text(
                          'KORLANTAS HUTANG TEMAN REPUBLIK INDONESIA',
                          style: TextStyle(fontSize: 10, letterSpacing: 0.5),
                        ),
                      ),
                      const Divider(thickness: 2, color: Colors.red),
                    ] else ...[
                      Center(
                        child: Text(
                          widget.settings.title.toUpperCase(),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1),
                        ),
                      ),
                      const Center(
                        child: Text('OFFICIAL PAYMENT RECEIPT',
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ),
                      const Divider(),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Pelanggar / Debtor:'),
                        Text(b.participant.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('RINCIAN KONSUMSI:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    ...b.shares.map((s) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${s.itemName} (x${s.quantity})',
                                  style: const TextStyle(fontSize: 13)),
                              Text(widget.formatMoney(s.amount),
                                  style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tax & Service:'),
                        Text(widget.formatMoney(b.tax + b.service)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL WAJIB TRANSFER:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            widget.formatMoney(b.total),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Payment Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.grey.shade400,
                            style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('REKENING PENAMPUNG:',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                              '${widget.payment.provider}: ${widget.payment.accountNumber}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('a/n ${widget.payment.accountName}',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: generateShareText()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Debt text copied to clipboard! Ready for WhatsApp 📋')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Text'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF25D366), // WhatsApp Green
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: generateShareText()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Opening WhatsApp template...')),
                      );
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Share WhatsApp'),
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
