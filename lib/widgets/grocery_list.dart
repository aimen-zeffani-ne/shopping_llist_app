import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shopping_list_app/data/categories.dart';
import 'package:shopping_list_app/models/grocery_item.dart';
import 'package:shopping_list_app/widgets/new_item.dart';

class GroceryList extends StatefulWidget {
  const GroceryList({super.key});

  @override
  State<GroceryList> createState() => _GroceryListState();
}

class _GroceryListState extends State<GroceryList> {
  late Future<List<GroceryItem>> _groceryItemsFuture;

  @override
  void initState() {
    super.initState();
    _groceryItemsFuture = _fetchGroceryItems();
  }

  /// Fetch grocery items from the backend.
  Future<List<GroceryItem>> _fetchGroceryItems() async {
    final url = Uri.https(
      'shopping-list-app-dac53-default-rtdb.europe-west1.firebasedatabase.app',
      'shopping-list.json',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode >= 400) {
        throw Exception('Failed to fetch data. Please try again later.');
      }

      if (response.body == 'null') {
        return [];
      }

      final Map<String, dynamic> listData = json.decode(response.body);
      return listData.entries.map((entry) {
        final category = categories.entries
            .firstWhere((cat) => cat.value.title == entry.value['category'])
            .value;

        return GroceryItem(
          id: entry.key,
          name: entry.value['name'],
          quantity: entry.value['quantity'],
          category: category,
        );
      }).toList();
    } catch (error) {
      throw Exception('Something went wrong. Please try again.');
    }
  }

  /// Add a new grocery item.
  Future<void> _addItem() async {
    final newItem = await Navigator.of(context).push<GroceryItem>(
      MaterialPageRoute(
        builder: (ctx) => const NewItem(),
      ),
    );

    if (newItem != null) {
      setState(() {
        _groceryItemsFuture = _fetchGroceryItems();
      });
    }
  }

  /// Remove a grocery item with undo functionality.
  void _removeItem(GroceryItem item) {
    final url = Uri.https(
      'shopping-list-app-dac53-default-rtdb.europe-west1.firebasedatabase.app',
      'shopping-list/${item.id}.json',
    );

    http.delete(url).then((response) {
      if (response.statusCode >= 400) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete the item.')),
        );
      } else {
        setState(() {
          _groceryItemsFuture = _fetchGroceryItems();
        });
      }
    }).catchError((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete the item.')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Groceries'),
        actions: [
          IconButton(
            onPressed: _addItem,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: FutureBuilder<List<GroceryItem>>(
        future: _groceryItemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(color: Colors.red),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No items added yet! Start by adding some.'),
            );
          } else {
            final groceryItems = snapshot.data!;
            return ListView.builder(
              itemCount: groceryItems.length,
              itemBuilder: (ctx, index) => Dismissible(
                key: ValueKey(groceryItems[index].id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => _removeItem(groceryItems[index]),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: ListTile(
                  title: Text(groceryItems[index].name),
                  leading: Container(
                    width: 24,
                    height: 24,
                    color: groceryItems[index].category.color,
                  ),
                  trailing: Text(groceryItems[index].quantity.toString()),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
