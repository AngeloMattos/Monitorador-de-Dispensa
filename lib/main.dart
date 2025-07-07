import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // Required for JSON encoding/decoding

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitorador de Despensa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
    );
  }
}

class Produto {
  String nome;
  DateTime validade;
  int quantidade;

  Produto({required this.nome, required this.validade, required this.quantidade});

  // Convert a Produto object to a JSON map
  Map<String, dynamic> toJson() => {
        'nome': nome,
        'validade': validade.toIso8601String(), // Store date as ISO string
        'quantidade': quantidade,
      };

  // Create a Produto object from a JSON map
  factory Produto.fromJson(Map<String, dynamic> json) => Produto(
        nome: json['nome'],
        validade: DateTime.parse(json['validade']),
        quantidade: json['quantidade'],
      );

  // Getter to check if the product is expired
  bool get isExpired {
    final hoje = DateTime.now();
    return validade.isBefore(hoje.subtract(const Duration(days: 1))); // Consider past midnight as expired
  }

  // Getter to check if the product is near expiration (within 3 days)
  bool get pertoDoVencimento {
    final hoje = DateTime.now();
    final diasRestantes = validade.difference(hoje).inDays;
    return diasRestantes <= 3 && diasRestantes >= 0; // Near expiration, but not expired yet
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Produto> produtos = [];

  final TextEditingController nomeController = TextEditingController();
  final TextEditingController validadeController = TextEditingController();
  final TextEditingController quantidadeController = TextEditingController();

  // Initialize SharedPreferences
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initSharedPreferences();
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _loadProdutos();
  }

  // Load products from SharedPreferences
  void _loadProdutos() {
    final String? produtosJsonString = _prefs.getString('produtos_list');
    if (produtosJsonString != null) {
      final List<dynamic> jsonList = json.decode(produtosJsonString);
      setState(() {
        produtos = jsonList.map((jsonItem) => Produto.fromJson(jsonItem)).toList();
      });
    }
  }

  // Save products to SharedPreferences
  void _saveProdutos() {
    final List<Map<String, dynamic>> jsonList = produtos.map((produto) => produto.toJson()).toList();
    _prefs.setString('produtos_list', json.encode(jsonList));
  }

  // Function to show a SnackBar message
  void _showSnackBar(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Function to select date
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      validadeController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  void adicionarProduto() {
    final String nome = nomeController.text.trim();
    final DateTime? validade = DateTime.tryParse(validadeController.text);
    final int? quantidade = int.tryParse(quantidadeController.text);

    if (nome.isEmpty) {
      _showSnackBar('O nome do produto não pode estar vazio.', backgroundColor: Colors.red);
      return;
    }
    if (validade == null) {
      _showSnackBar('Por favor, selecione uma data de validade válida.', backgroundColor: Colors.red);
      return;
    }
    if (quantidade == null || quantidade <= 0) {
      _showSnackBar('A quantidade deve ser um número inteiro positivo.', backgroundColor: Colors.red);
      return;
    }

    setState(() {
      produtos.add(Produto(nome: nome, validade: validade, quantidade: quantidade));
      _saveProdutos(); // Save after adding
    });

    nomeController.clear();
    validadeController.clear();
    quantidadeController.clear();
    _showSnackBar('Produto "$nome" adicionado com sucesso!');
  }

  void darBaixaProduto(int index) {
    setState(() {
      if (produtos[index].quantidade > 1) {
        produtos[index].quantidade--;
        _showSnackBar('Uma unidade de "${produtos[index].nome}" foi removida.');
      } else {
        final String removedName = produtos[index].nome;
        produtos.removeAt(index);
        _showSnackBar('"$removedName" foi removido da despensa.');
      }
      _saveProdutos(); // Save after changing quantity
    });
  }

  void adicionarUnidade(int index) {
    setState(() {
      produtos[index].quantidade++;
      _saveProdutos(); // Save after changing quantity
      _showSnackBar('Uma unidade de "${produtos[index].nome}" foi adicionada.');
    });
  }

  String formatarData(DateTime data) {
    return DateFormat('dd/MM/yyyy').format(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monitorador de Despensa')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome do Produto',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: validadeController,
              readOnly: true, // Make text field read-only to force date picker
              onTap: () => _selectDate(context),
              decoration: const InputDecoration(
                labelText: 'Data de Validade',
                hintText: 'Toque para selecionar a data',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: quantidadeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantidade',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: adicionarProduto,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Produto', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              'Produtos na Despensa:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: produtos.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum produto na despensa ainda. Adicione um!',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: produtos.length,
                      itemBuilder: (context, index) {
                        final produto = produtos[index];
                        Color? cardColor;
                        String statusText = '';
                        if (produto.isExpired) {
                          cardColor = Colors.red[300]; // Darker red for expired
                          statusText = 'VENCIDO';
                        } else if (produto.pertoDoVencimento) {
                          cardColor = Colors.orange[200]; // Orange for near expiration
                          statusText = 'VENCE EM BREVE';
                        }

                        return Card(
                          color: cardColor,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: cardColor ?? Colors.green,
                                child: Text(
                                  produto.quantidade.toString(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                produto.nome,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: produto.isExpired ? TextDecoration.lineThrough : null, // Strikethrough if expired
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Validade: ${formatarData(produto.validade)}'),
                                  if (statusText.isNotEmpty)
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        color: produto.isExpired ? Colors.white : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.add_circle, color: Colors.green),
                                    onPressed: () => adicionarUnidade(index),
                                    tooltip: 'Adicionar 1 unidade',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                                    onPressed: () => darBaixaProduto(index),
                                    tooltip: 'Remover 1 unidade ou produto',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}