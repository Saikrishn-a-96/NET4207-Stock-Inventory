import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Use the firebase_options.dart generated for the lecturer-provided project.
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const StockInventoryApp());
}

const categories = ['Electronics', 'Stationery', 'Hardware', 'Grocery'];

class StockInventoryApp extends StatelessWidget {
  const StockInventoryApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Stock Inventory Manager',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const InventoryPage(),
      );
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _sku = TextEditingController();
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _reorder = TextEditingController();
  final _keyword = TextEditingController();
  String? _category;
  String _categoryFilter = 'All';
  bool _lowStockOnly = false;
  bool _ascending = true;
  bool _saving = false;
  bool _loading = true;
  String? _loadError;
  List<Map<String, dynamic>> _items = [];

  CollectionReference<Map<String, dynamic>> get _stock =>
      FirebaseFirestore.instance.collection('stockItems');

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    for (final c in [_sku, _name, _quantity, _price, _reorder, _keyword]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final snapshot = await _stock.get();
      final loaded = snapshot.docs.map((doc) => <String, dynamic>{
        ...doc.data(), '_documentId': doc.id,
      }).toList();
      if (!mounted) return;
      setState(() { _items = loaded; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadError = 'Could not load inventory. Check your connection and access rules.'; _loading = false; });
    }
  }

  String? _validateSku(String? value) {
    final v = value?.trim() ?? '';
    return RegExp(r'^STK-\d{3}$').hasMatch(v)
        ? null : 'Enter a SKU in the format STK-101.';
  }

  String? _validateName(String? value) => (value?.trim().length ?? 0) >= 3
      ? null : 'Item name must contain at least 3 characters.';

  String? _validateInteger(String? value, String label) {
    final n = int.tryParse(value?.trim() ?? '');
    return n == null || n < 0 ? '$label must be a whole number of 0 or more.' : null;
  }

  String? _validatePrice(String? value) {
    final n = double.tryParse(value?.trim() ?? '');
    return n == null || !n.isFinite || n <= 0
        ? 'Enter a price greater than RM 0.' : null;
  }

  Future<void> _saveItem() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _stock.add({
        'sku': _sku.text.trim(),
        'itemName': _name.text.trim(),
        'category': _category!,
        'quantity': int.parse(_quantity.text.trim()),
        'unitPrice': double.parse(_price.text.trim()),
        'reorderLevel': int.parse(_reorder.text.trim()),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _formKey.currentState!.reset();
      for (final c in [_sku, _name, _quantity, _price, _reorder]) { c.clear(); }
      setState(() { _category = null; _saving = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item saved to Firestore.')),
      );
      await _loadItems();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Save failed (${e.code}). Your form values are still available.'),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save failed. Your form values are still available.')),
      );
    }
  }

  List<Map<String, dynamic>> get _visibleItems {
    final q = _keyword.text.trim().toLowerCase();
    final result = _items.where((item) {
      final sku = (item['sku'] ?? '').toString().toLowerCase();
      final name = (item['itemName'] ?? '').toString().toLowerCase();
      final categoryMatches = _categoryFilter == 'All' || item['category'] == _categoryFilter;
      final quantity = item['quantity'] as num? ?? 0;
      final reorder = item['reorderLevel'] as num? ?? 0;
      return (q.isEmpty || name.contains(q) || sku.contains(q)) &&
          categoryMatches && (!_lowStockOnly || quantity <= reorder);
    }).toList();
    result.sort((a, b) {
      final comparison = ((a['quantity'] as num?) ?? 0)
          .compareTo((b['quantity'] as num?) ?? 0);
      return _ascending ? comparison : -comparison;
    });
    return result;
  }

  void _clearFilters() {
    _keyword.clear();
    setState(() { _categoryFilter = 'All'; _lowStockOnly = false; _ascending = true; });
  }

  Widget _buildForm() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Add stock item', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextFormField(controller: _sku, decoration: const InputDecoration(labelText: 'SKU', hintText: 'STK-101'), validator: _validateSku, textCapitalization: TextCapitalization.characters),
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Item name'), validator: _validateName),
          DropdownButtonFormField<String>(
            value: _category, decoration: const InputDecoration(labelText: 'Category'),
            items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _category = v),
            validator: (v) => v == null ? 'Choose a category.' : null,
          ),
          TextFormField(controller: _quantity, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: (v) => _validateInteger(v, 'Quantity')),
          TextFormField(controller: _price, decoration: const InputDecoration(labelText: 'Unit price (RM)'), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))], validator: _validatePrice),
          TextFormField(controller: _reorder, decoration: const InputDecoration(labelText: 'Reorder level'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: (v) => _validateInteger(v, 'Reorder level')),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _saving ? null : _saveItem, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save), label: Text(_saving ? 'Saving…' : 'Save item')),
        ]),
      ),
    ),
  );

  Widget _buildInventory() {
    final visible = _visibleItems;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Inventory', style: Theme.of(context).textTheme.titleLarge),
      TextField(controller: _keyword, decoration: const InputDecoration(labelText: 'Search SKU or item name', prefixIcon: Icon(Icons.search)), onChanged: (_) => setState(() {})),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(value: _categoryFilter, decoration: const InputDecoration(labelText: 'Category filter'), items: ['All', ...categories].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _categoryFilter = v ?? 'All')),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Low stock only'), subtitle: const Text('Quantity ≤ reorder level'), value: _lowStockOnly, onChanged: (v) => setState(() => _lowStockOnly = v)),
      Row(children: [const Text('Sort quantity:'), const SizedBox(width: 8), TextButton.icon(onPressed: () => setState(() => _ascending = !_ascending), icon: Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward), label: Text(_ascending ? 'Ascending' : 'Descending')), const Spacer(), TextButton(onPressed: _clearFilters, child: const Text('Clear filters'))]),
      if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
      else if (_loadError != null) Card(child: ListTile(leading: const Icon(Icons.error_outline), title: Text(_loadError!), trailing: TextButton(onPressed: _loadItems, child: const Text('Retry'))))
      else if (visible.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(_items.isEmpty ? 'No stock items saved yet.' : 'No items match these filters.')))
      else ...visible.map(_itemCard),
      Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _loadItems, icon: const Icon(Icons.refresh), label: const Text('Reload inventory'))),
    ]);
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final price = (item['unitPrice'] as num?)?.toStringAsFixed(2) ?? '0.00';
    final quantity = item['quantity'] as num? ?? 0;
    final reorderLevel = item['reorderLevel'] as num? ?? 0;
    final isLowStock = quantity <= reorderLevel;
    final warningColor = Theme.of(context).colorScheme.error;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isLowStock ? warningColor.withOpacity(0.045) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLowStock ? BorderSide(color: warningColor, width: 1.4) : BorderSide.none,
      ),
      child: ListTile(
        title: Row(children: [
          Expanded(child: Text('${item['itemName']}  •  ${item['sku']}')) ,
          if (isLowStock) Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: warningColor.withOpacity(0.08),
              border: Border.all(color: warningColor),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.warning_amber_rounded, size: 15, color: warningColor),
              const SizedBox(width: 4),
              Text('LOW STOCK', style: TextStyle(color: warningColor, fontWeight: FontWeight.bold, fontSize: 11)),
            ]),
          ),
        ]),
        subtitle: Text('${item['category']}  |  Qty: ${item['quantity']}  |  RM $price  |  Reorder at: ${item['reorderLevel']}'),
        isThreeLine: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Stock Inventory Manager')),
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildForm(), const SizedBox(height: 24), _buildInventory(),
    ]))))),
  );
}
