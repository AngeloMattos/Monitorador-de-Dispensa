import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() => runApp(const MyApp());

enum ProductFilter {
  all,
  expired,
  nearExpiration,
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitorador de Despensa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal).copyWith(
          secondary: Colors.amber,
        ),
        scaffoldBackgroundColor: Colors.teal[50],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.teal[700],
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.teal.shade200, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.teal.shade700, width: 2),
          ),
          labelStyle: TextStyle(color: Colors.teal[800]),
          hintStyle: TextStyle(color: Colors.grey[500]),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        ),
        listTileTheme: ListTileThemeData(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.grey[800],
          contentTextStyle: const TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          actionTextColor: Colors.amberAccent,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class Produto {
  String nome;
  DateTime validade;
  int quantidade;
  String? categoria;
  String? localArmazenamento;

  Produto({
    required this.nome,
    required this.validade,
    required this.quantidade,
    this.categoria,
    this.localArmazenamento,
  });

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'validade': validade.toIso8601String(),
    'quantidade': quantidade,
    'categoria': categoria,
    'localArmazenamento': localArmazenamento,
  };

  factory Produto.fromJson(Map<String, dynamic> json) => Produto(
    nome: json['nome'],
    validade: DateTime.parse(json['validade']),
    quantidade: json['quantidade'],
    categoria: json['categoria'],
    localArmazenamento: json['localArmazenamento'],
  );

  bool get isExpired {
    final hoje = DateTime.now();
    return validade.year < hoje.year ||
        (validade.year == hoje.year && validade.month < hoje.month) ||
        (validade.year == hoje.year && validade.month == hoje.month && hoje.day > validade.day);
  }

  bool get pertoDoVencimento {
    final hoje = DateTime.now();
    final validadeMidnight = DateTime(validade.year, validade.month, validade.day);
    final hojeMidnight = DateTime(hoje.year, hoje.month, hoje.day);
    final diasRestantes = validadeMidnight.difference(hojeMidnight).inDays;
    return diasRestantes >= 0 && diasRestantes <= 3 && !isExpired;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Produto> produtos = [];
  List<Produto> _filteredProdutos = [];

  final TextEditingController nomeController = TextEditingController();
  final TextEditingController validadeController = TextEditingController();
  final TextEditingController quantidadeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController categoriaController = TextEditingController();
  final TextEditingController localArmazenamentoController = TextEditingController();

  ProductFilter _selectedFilter = ProductFilter.all;

  bool _useCategory = false;
  bool _useLocation = false;
  bool _showFilterOptions = false; // NOVA VARIÁVEL DE ESTADO

  String? _selectedCategoryFilter;
  String? _selectedLocationFilter;

  List<String> _uniqueCategories = ['Todos'];
  List<String> _uniqueLocations = ['Todos'];

  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initSharedPreferences();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    nomeController.dispose();
    validadeController.dispose();
    quantidadeController.dispose();
    categoriaController.dispose();
    localArmazenamentoController.dispose();
    super.dispose();
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _loadProdutos();
  }

  void _loadProdutos() {
    final String? produtosJsonString = _prefs.getString('produtos_list');
    if (produtosJsonString != null) {
      final List<dynamic> jsonList = json.decode(produtosJsonString);
      setState(() {
        produtos = jsonList.map((jsonItem) => Produto.fromJson(jsonItem)).toList();
        _sortProdutos();
        _updateUniqueFilters();
        _applyFilters();
      });
    }
  }

  void _saveProdutos() {
    final List<Map<String, dynamic>> jsonList = produtos.map((produto) => produto.toJson()).toList();
    _prefs.setString('produtos_list', json.encode(jsonList));
  }

  void _sortProdutos() {
    produtos.sort((a, b) {
      if (a.isExpired && !b.isExpired) return -1;
      if (!a.isExpired && b.isExpired) return 1;
      if (a.pertoDoVencimento && !b.pertoDoVencimento) return -1;
      if (!a.pertoDoVencimento && b.pertoDoVencimento) return 1;
      return a.validade.compareTo(b.validade);
    });
  }

  void _updateUniqueFilters() {
    Set<String> categories = {};
    Set<String> locations = {};

    for (var produto in produtos) {
      if (produto.categoria != null && produto.categoria!.isNotEmpty) {
        categories.add(produto.categoria!);
      }
      if (produto.localArmazenamento != null && produto.localArmazenamento!.isNotEmpty) {
        locations.add(produto.localArmazenamento!);
      }
    }

    setState(() {
      _uniqueCategories = ['Todos', ...categories.toList()..sort()];
      _uniqueLocations = ['Todos', ...locations.toList()..sort()];

      if (_selectedCategoryFilter != null && !_uniqueCategories.contains(_selectedCategoryFilter)) {
        _selectedCategoryFilter = 'Todos';
      }
      if (_selectedLocationFilter != null && !_uniqueLocations.contains(_selectedLocationFilter)) {
        _selectedLocationFilter = 'Todos';
      }
    });
  }

  void _applyFilters() {
    List<Produto> tempFilteredList = produtos;

    final String query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      tempFilteredList = tempFilteredList
          .where((produto) => produto.nome.toLowerCase().contains(query))
          .toList();
    }

    if (_selectedFilter == ProductFilter.expired) {
      tempFilteredList = tempFilteredList.where((produto) => produto.isExpired).toList();
    } else if (_selectedFilter == ProductFilter.nearExpiration) {
      tempFilteredList = tempFilteredList.where((produto) => produto.pertoDoVencimento).toList();
    }

    if (_selectedCategoryFilter != null && _selectedCategoryFilter != 'Todos') {
      tempFilteredList = tempFilteredList
          .where((produto) => produto.categoria == _selectedCategoryFilter)
          .toList();
    }

    if (_selectedLocationFilter != null && _selectedLocationFilter != 'Todos') {
      tempFilteredList = tempFilteredList
          .where((produto) => produto.localArmazenamento == _selectedLocationFilter)
          .toList();
    }

    setState(() {
      _filteredProdutos = tempFilteredList;
    });
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _showSnackBar(String message, {Color? backgroundColor, SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Theme.of(context).snackBarTheme.backgroundColor,
        duration: const Duration(seconds: 2),
        action: action,
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      validadeController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  void adicionarProduto() {
    final String nome = nomeController.text.trim();
    final DateTime? validade = DateTime.tryParse(validadeController.text);
    final int? quantidade = int.tryParse(quantidadeController.text);
    final String? categoria = _useCategory ? categoriaController.text.trim() : null;
    final String? localArmazenamento = _useLocation ? localArmazenamentoController.text.trim() : null;

    if (nome.isEmpty) {
      _showSnackBar('O nome do produto não pode estar vazio.', backgroundColor: Colors.red[700]);
      return;
    }
    if (validade == null) {
      _showSnackBar('Por favor, selecione uma data de validade válida.', backgroundColor: Colors.red[700]);
      return;
    }
    if (quantidade == null || quantidade <= 0) {
      _showSnackBar('A quantidade deve ser um número inteiro positivo.', backgroundColor: Colors.red[700]);
      return;
    }
    if (_useCategory && (categoria == null || categoria.isEmpty)) {
      _showSnackBar('A categoria não pode estar vazia se a opção estiver marcada.', backgroundColor: Colors.red[700]);
      return;
    }
    if (_useLocation && (localArmazenamento == null || localArmazenamento.isEmpty)) {
      _showSnackBar('O local de armazenamento não pode estar vazio se a opção estiver marcada.', backgroundColor: Colors.red[700]);
      return;
    }

    setState(() {
      produtos.add(Produto(
        nome: nome,
        validade: validade,
        quantidade: quantidade,
        categoria: categoria,
        localArmazenamento: localArmazenamento,
      ));
      _sortProdutos();
      _saveProdutos();
      _updateUniqueFilters();
      _applyFilters();
    });

    nomeController.clear();
    validadeController.clear();
    quantidadeController.clear();
    categoriaController.clear();
    localArmazenamentoController.clear();
    _showSnackBar('Produto "$nome" adicionado com sucesso!', backgroundColor: Colors.green[700]);
  }

  void darBaixaProduto(int index) {
    final Produto produtoRemovido = _filteredProdutos[index];
    final int originalIndex = produtos.indexOf(produtoRemovido);

    if (originalIndex != -1) {
      setState(() {
        if (produtos[originalIndex].quantidade > 1) {
          produtos[originalIndex].quantidade--;
          _showSnackBar('Uma unidade de "${produtos[originalIndex].nome}" foi removida.');
        } else {
          produtos.removeAt(originalIndex);
          _showSnackBar('"${produtoRemovido.nome}" foi removido da despensa.',
              action: SnackBarAction(
                label: 'Desfazer',
                onPressed: () {
                  setState(() {
                    _loadProdutos();
                  });
                },
              ));
        }
        _sortProdutos();
        _saveProdutos();
        _updateUniqueFilters();
        _applyFilters();
      });
    }
  }

  void adicionarUnidade(int index) {
    final Produto produtoAdicionado = _filteredProdutos[index];
    final int originalIndex = produtos.indexOf(produtoAdicionado);

    if (originalIndex != -1) {
      setState(() {
        produtos[originalIndex].quantidade++;
        _sortProdutos();
        _saveProdutos();
        _updateUniqueFilters();
        _applyFilters();
        _showSnackBar('Uma unidade de "${produtos[originalIndex].nome}" foi adicionada.');
      });
    }
  }

  String formatarData(DateTime data) {
    return DateFormat('dd/MM/yyyy').format(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitorador de Despensa'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Campos de entrada de novo produto
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome do Produto',
                prefixIcon: Icon(Icons.shopping_basket, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: validadeController,
              readOnly: true,
              onTap: () => _selectDate(context),
              decoration: const InputDecoration(
                labelText: 'Data de Validade',
                hintText: 'Toque para selecionar a data',
                prefixIcon: Icon(Icons.calendar_today, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: quantidadeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantidade',
                prefixIcon: Icon(Icons.format_list_numbered, size: 20),
              ),
            ),
            const SizedBox(height: 16),

            // Switches para Categoria e Local
            SwitchListTile(
              title: const Text('Adicionar Categoria (Opcional)', style: TextStyle(fontSize: 14)),
              value: _useCategory,
              onChanged: (bool value) {
                setState(() {
                  _useCategory = value;
                  if (!value) {
                    categoriaController.clear();
                  }
                });
              },
              activeColor: Theme.of(context).primaryColor,
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            if (_useCategory)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: TextField(
                  controller: categoriaController,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    hintText: 'Ex: Laticínios, Grãos',
                    prefixIcon: Icon(Icons.category, size: 20),
                  ),
                ),
              ),

            SwitchListTile(
              title: const Text('Adicionar Local (Opcional)', style: TextStyle(fontSize: 14)),
              value: _useLocation,
              onChanged: (bool value) {
                setState(() {
                  _useLocation = value;
                  if (!value) {
                    localArmazenamentoController.clear();
                  }
                });
              },
              activeColor: Theme.of(context).primaryColor,
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            if (_useLocation)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextField(
                  controller: localArmazenamentoController,
                  decoration: const InputDecoration(
                    labelText: 'Local de Armazenamento',
                    hintText: 'Ex: Geladeira, Armário',
                    prefixIcon: Icon(Icons.location_on, size: 20),
                  ),
                ),
              ),

            ElevatedButton.icon(
              onPressed: adicionarProduto,
              icon: const Icon(Icons.add_shopping_cart, size: 20),
              label: const Text('Adicionar Produto'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(45),
              ),
            ),
            const SizedBox(height: 25),

            // NOVO: BOTÃO PARA EXIBIR/ESCONDER FILTROS
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showFilterOptions = !_showFilterOptions;
                });
              },
              icon: Icon(_showFilterOptions ? Icons.filter_alt_off : Icons.filter_alt, size: 20),
              label: Text(_showFilterOptions ? 'Esconder Filtros' : 'Mostrar Opções de Filtro'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(45),
                backgroundColor: Theme.of(context).colorScheme.secondary, // Cor de destaque
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // FILTROS: AGORA CONDICIONALMENTE VISÍVEIS
            Visibility(
              visible: _showFilterOptions,
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Pesquisar Produto',
                      hintText: 'Digite o nome do produto',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                      )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        SegmentedButton<ProductFilter>(
                          segments: const <ButtonSegment<ProductFilter>>[
                            ButtonSegment<ProductFilter>(
                              value: ProductFilter.all,
                              label: Text('Todos', style: TextStyle(fontSize: 12)),
                              icon: Icon(Icons.list, size: 16),
                            ),
                            ButtonSegment<ProductFilter>(
                              value: ProductFilter.nearExpiration,
                              label: Text('Vence em Breve', style: TextStyle(fontSize: 12)),
                              icon: Icon(Icons.warning_amber, size: 16),
                            ),
                            ButtonSegment<ProductFilter>(
                              value: ProductFilter.expired,
                              label: Text('Vencidos', style: TextStyle(fontSize: 12)),
                              icon: Icon(Icons.dangerous, size: 16),
                            ),
                          ],
                          selected: <ProductFilter>{_selectedFilter},
                          onSelectionChanged: (Set<ProductFilter> newSelection) {
                            setState(() {
                              _selectedFilter = newSelection.first;
                              _applyFilters();
                            });
                          },
                          style: SegmentedButton.styleFrom(
                            foregroundColor: Colors.teal[800],
                            selectedForegroundColor: Colors.white,
                            selectedBackgroundColor: Colors.teal,
                            side: BorderSide(color: Colors.teal.shade200),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                        // Dropdown para Categoria
                        ConstrainedBox( // Limita a largura do dropdown
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width / 2 - 20), // Ajuste conforme necessário
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategoryFilter ?? 'Todos',
                            decoration: const InputDecoration(
                              labelText: 'Categoria',
                              prefixIcon: Icon(Icons.category, size: 20),
                              contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                            ),
                            items: _uniqueCategories.map((String category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(category, style: const TextStyle(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedCategoryFilter = newValue;
                                _applyFilters();
                              });
                            },
                            isDense: true,
                          ),
                        ),
                        // Dropdown para Local de Armazenamento
                        ConstrainedBox( // Limita a largura do dropdown
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width / 2 - 20), // Ajuste conforme necessário
                          child: DropdownButtonFormField<String>(
                            value: _selectedLocationFilter ?? 'Todos',
                            decoration: const InputDecoration(
                              labelText: 'Local',
                              prefixIcon: Icon(Icons.location_on, size: 20),
                              contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                            ),
                            items: _uniqueLocations.map((String location) {
                              return DropdownMenuItem<String>(
                                value: location,
                                child: Text(location, style: const TextStyle(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedLocationFilter = newValue;
                                _applyFilters();
                              });
                            },
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20), // Espaçamento após os filtros quando visíveis
                ],
              ),
            ),

            const Text(
              'Meus Produtos na Despensa',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: _filteredProdutos.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _searchController.text.isEmpty && _selectedFilter == ProductFilter.all &&
                          (_selectedCategoryFilter == null || _selectedCategoryFilter == 'Todos') &&
                          (_selectedLocationFilter == null || _selectedLocationFilter == 'Todos')
                          ? Icons.inbox_outlined
                          : Icons.search_off,
                      size: 70,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _searchController.text.isEmpty && _selectedFilter == ProductFilter.all &&
                          (_selectedCategoryFilter == null || _selectedCategoryFilter == 'Todos') &&
                          (_selectedLocationFilter == null || _selectedLocationFilter == 'Todos')
                          ? 'Sua despensa está vazia!\nAdicione alguns produtos para começar.'
                          : 'Nenhum produto encontrado com os filtros selecionados.',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _filteredProdutos.length,
                itemBuilder: (context, index) {
                  final produto = _filteredProdutos[index];
                  Color? cardColor;
                  String statusText = '';
                  Color? statusTextColor;

                  if (produto.isExpired) {
                    cardColor = Colors.red[100];
                    statusText = 'VENCIDO';
                    statusTextColor = Colors.red[800];
                  } else if (produto.pertoDoVencimento) {
                    cardColor = Colors.orange[100];
                    statusText = 'VENCE EM BREVE';
                    statusTextColor = Colors.orange[800];
                  } else {
                    cardColor = Colors.white;
                  }

                  return Card(
                    color: cardColor,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.teal[200],
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            produto.quantidade.toString(),
                            style: TextStyle(
                              color: Colors.teal[900],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        title: Text(
                          produto.nome,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.teal[900],
                            decoration: produto.isExpired ? TextDecoration.lineThrough : null,
                            decorationThickness: 2,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              'Validade: ${formatarData(produto.validade)}',
                              style: TextStyle(color: Colors.grey[700], fontSize: 12),
                            ),
                            if (produto.categoria != null && produto.categoria!.isNotEmpty)
                              Text(
                                'Categoria: ${produto.categoria}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                              ),
                            if (produto.localArmazenamento != null && produto.localArmazenamento!.isNotEmpty)
                              Text(
                                'Local: ${produto.localArmazenamento}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                              ),
                            if (statusText.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 3.0),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusTextColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.add_circle, color: Colors.teal[600], size: 26),
                              onPressed: () => adicionarUnidade(index),
                              tooltip: 'Adicionar 1 unidade',
                            ),
                            IconButton(
                              icon: Icon(Icons.remove_circle, color: Colors.red[600], size: 26),
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