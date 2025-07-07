import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // Necessário para codificação/decodificação JSON

void main() => runApp(const MyApp());

// Enum para os tipos de filtro de produto
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
        // Define um esquema de cores consistente para toda a aplicação
          primarySwatch: Colors.teal, // Um verde-azulado calmante
          colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal).copyWith(
            secondary: Colors.amber, // Uma cor vibrante para o botão de ação flutuante, etc.
          ),
          scaffoldBackgroundColor: Colors.teal[50], // Fundo claro para uma sensação de frescor
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.teal[700], // Teal mais escuro para a barra do aplicativo
            foregroundColor: Colors.white, // Texto branco na barra do aplicativo
            elevation: 4, // Adiciona uma sombra sutil
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white, // Fundo branco para os campos de entrada
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), // Bordas arredondadas
              borderSide: BorderSide.none, // Sem borda visível inicialmente
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.teal.shade200, width: 1), // Borda clara quando habilitado
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.teal.shade700, width: 2), // Borda mais forte quando focado
            ),
            labelStyle: TextStyle(color: Colors.teal[800]), // Cor do texto do rótulo
            hintStyle: TextStyle(color: Colors.grey[500]),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal, // Cor do botão
              foregroundColor: Colors.white, // Cor do texto do botão
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12), // Botões arredondados
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          cardTheme: CardThemeData( // CORREÇÃO: Usando CardThemeData
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15), // Cartões mais arredondados
            ),
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), // Margem um pouco maior
          ),
          listTileTheme: ListTileThemeData(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: Colors.grey[800], // Snackbar mais escura para melhor contraste
            contentTextStyle: const TextStyle(color: Colors.white),
            behavior: SnackBarBehavior.floating, // Snackbar flutuante
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            actionTextColor: Colors.amberAccent,
          )
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

  // Converte um objeto Produto para um mapa JSON
  Map<String, dynamic> toJson() => {
    'nome': nome,
    'validade': validade.toIso8601String(), // Armazena a data como string ISO
    'quantidade': quantidade,
  };

  // Cria um objeto Produto a partir de um mapa JSON
  factory Produto.fromJson(Map<String, dynamic> json) => Produto(
    nome: json['nome'],
    validade: DateTime.parse(json['validade']),
    quantidade: json['quantidade'],
  );

  // Getter para verificar se o produto está vencido
  bool get isExpired {
    final hoje = DateTime.now();
    // Compara apenas as datas, ignorando a hora
    return validade.year < hoje.year ||
        (validade.year == hoje.year && validade.month < hoje.month) ||
        (validade.year == hoje.year && validade.month == hoje.month && validade.day < hoje.day);
  }

  // Getter para verificar se o produto está perto do vencimento (dentro de 3 dias, incluindo hoje)
  bool get pertoDoVencimento {
    final hoje = DateTime.now();
    final validadeMidnight = DateTime(validade.year, validade.month, validade.day);
    final hojeMidnight = DateTime(hoje.year, hoje.month, hoje.day);
    final diasRestantes = validadeMidnight.difference(hojeMidnight).inDays;
    return diasRestantes >= 0 && diasRestantes <= 3 && !isExpired; // Perto do vencimento, mas ainda não vencido
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Produto> produtos = [];
  List<Produto> _filteredProdutos = []; // Nova lista para produtos filtrados

  final TextEditingController nomeController = TextEditingController();
  final TextEditingController validadeController = TextEditingController();
  final TextEditingController quantidadeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController(); // Controlador para a barra de pesquisa

  ProductFilter _selectedFilter = ProductFilter.all; // Estado do filtro selecionado

  // Inicializa SharedPreferences
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initSharedPreferences();
    // Adiciona um listener ao controlador de pesquisa para filtrar produtos em tempo real
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    nomeController.dispose();
    validadeController.dispose();
    quantidadeController.dispose();
    super.dispose();
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _loadProdutos();
  }

  // Carrega produtos do SharedPreferences
  void _loadProdutos() {
    final String? produtosJsonString = _prefs.getString('produtos_list');
    if (produtosJsonString != null) {
      final List<dynamic> jsonList = json.decode(produtosJsonString);
      setState(() {
        produtos = jsonList.map((jsonItem) => Produto.fromJson(jsonItem)).toList();
        _sortProdutos(); // Ordena após carregar
        _applyFilters(); // Aplica os filtros e pesquisa após carregar
      });
    }
  }

  // Salva produtos no SharedPreferences
  void _saveProdutos() {
    final List<Map<String, dynamic>> jsonList = produtos.map((produto) => produto.toJson()).toList();
    _prefs.setString('produtos_list', json.encode(jsonList));
  }

  // Ordena os produtos por status e depois por validade
  void _sortProdutos() {
    produtos.sort((a, b) {
      // Itens vencidos primeiro
      if (a.isExpired && !b.isExpired) return -1;
      if (!a.isExpired && b.isExpired) return 1;

      // Depois itens perto do vencimento
      if (a.pertoDoVencimento && !b.pertoDoVencimento) return -1;
      if (!a.pertoDoVencimento && b.pertoDoVencimento) return 1;

      // Caso contrário, ordena por data de validade (mais antiga primeiro)
      return a.validade.compareTo(b.validade);
    });
  }

  // Lógica central para aplicar filtros e pesquisa
  void _applyFilters() {
    List<Produto> tempFilteredList = produtos;

    // 1. Aplica o filtro de pesquisa por nome
    final String query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      tempFilteredList = tempFilteredList
          .where((produto) => produto.nome.toLowerCase().contains(query))
          .toList();
    }

    // 2. Aplica o filtro de status (Vencido, Perto do Vencimento)
    if (_selectedFilter == ProductFilter.expired) {
      tempFilteredList = tempFilteredList.where((produto) => produto.isExpired).toList();
    } else if (_selectedFilter == ProductFilter.nearExpiration) {
      tempFilteredList = tempFilteredList.where((produto) => produto.pertoDoVencimento).toList();
    }
    // Se _selectedFilter for ProductFilter.all, nenhuma filtragem adicional é feita aqui

    setState(() {
      _filteredProdutos = tempFilteredList;
    });
  }

  // Chamado quando o texto da pesquisa muda
  void _onSearchChanged() {
    _applyFilters(); // Chama a função central de aplicação de filtros
  }

  // Função para exibir uma mensagem SnackBar
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

  // Função para selecionar data
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
              primary: Theme.of(context).primaryColor, // Cor de fundo do cabeçalho
              onPrimary: Colors.white, // Cor do texto do cabeçalho
              onSurface: Colors.black, // Cor do texto do corpo
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor, // Cor do texto do botão
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

    setState(() {
      produtos.add(Produto(nome: nome, validade: validade, quantidade: quantidade));
      _sortProdutos(); // Ordena após adicionar
      _saveProdutos(); // Salva após adicionar
      _applyFilters(); // Atualiza a lista filtrada e pesquisada
    });

    nomeController.clear();
    validadeController.clear();
    quantidadeController.clear();
    _showSnackBar('Produto "$nome" adicionado com sucesso!', backgroundColor: Colors.green[700]);
  }

  void darBaixaProduto(int index) {
    // Encontrar o produto na lista original 'produtos' usando o produto filtrado
    final Produto produtoRemovido = _filteredProdutos[index];
    final int originalIndex = produtos.indexOf(produtoRemovido);

    if (originalIndex != -1) { // Verifica se o produto ainda existe na lista original
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
                    _loadProdutos(); // Recarrega para reverter se necessário.
                    // _applyFilters() já é chamado dentro de _loadProdutos
                  });
                },
              ));
        }
        _sortProdutos(); // Ordena após a modificação
        _saveProdutos(); // Salva após a alteração da quantidade
        _applyFilters(); // Refiltrar e pesquisar após a modificação
      });
    }
  }

  void adicionarUnidade(int index) {
    // Encontrar o produto na lista original 'produtos' usando o produto filtrado
    final Produto produtoAdicionado = _filteredProdutos[index];
    final int originalIndex = produtos.indexOf(produtoAdicionado);

    if (originalIndex != -1) {
      setState(() {
        produtos[originalIndex].quantidade++;
        _sortProdutos(); // Ordena após a modificação
        _saveProdutos(); // Salva após a alteração da quantidade
        _applyFilters(); // Refiltrar e pesquisar após a modificação
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
        centerTitle: true, // Centraliza o título da barra do aplicativo
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Campos de entrada de novo produto
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome do Produto',
                prefixIcon: Icon(Icons.shopping_basket), // Adiciona um ícone
              ),
            ),
            const SizedBox(height: 15), // Espaçamento aumentado
            TextField(
              controller: validadeController,
              readOnly: true,
              onTap: () => _selectDate(context),
              decoration: const InputDecoration(
                labelText: 'Data de Validade',
                hintText: 'Toque para selecionar a data',
                prefixIcon: Icon(Icons.calendar_today), // Adiciona um ícone
              ),
            ),
            const SizedBox(height: 15), // Espaçamento aumentado
            TextField(
              controller: quantidadeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantidade',
                prefixIcon: Icon(Icons.format_list_numbered), // Adiciona um ícone
              ),
            ),
            const SizedBox(height: 20), // Espaçamento aumentado
            ElevatedButton.icon(
              onPressed: adicionarProduto,
              icon: const Icon(Icons.add_shopping_cart), // Ícone mais específico
              label: const Text('Adicionar Produto'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50), // Faz o botão ocupar toda a largura
              ),
            ),
            const SizedBox(height: 30), // Espaçamento aumentado para separação de seção

            // BARRA DE PESQUISA
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Pesquisar Produto',
                hintText: 'Digite o nome do produto',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilters(); // Limpa o filtro de pesquisa e reaplica os outros
                  },
                )
                    : null,
              ),
            ),
            const SizedBox(height: 20), // Espaçamento após a barra de pesquisa

            // BARRA DE FILTRO ADICIONADA AQUI
            Align(
              alignment: Alignment.centerLeft, // Alinha o SegmentedButton à esquerda
              child: SegmentedButton<ProductFilter>(
                segments: const <ButtonSegment<ProductFilter>>[
                  ButtonSegment<ProductFilter>(
                    value: ProductFilter.all,
                    label: Text('Todos'),
                    icon: Icon(Icons.list),
                  ),
                  ButtonSegment<ProductFilter>(
                    value: ProductFilter.nearExpiration,
                    label: Text('Vence em Breve'),
                    icon: Icon(Icons.warning_amber),
                  ),
                  ButtonSegment<ProductFilter>(
                    value: ProductFilter.expired,
                    label: Text('Vencidos'),
                    icon: Icon(Icons.dangerous),
                  ),
                ],
                selected: <ProductFilter>{_selectedFilter},
                onSelectionChanged: (Set<ProductFilter> newSelection) {
                  setState(() {
                    _selectedFilter = newSelection.first;
                    _applyFilters(); // Aplica o novo filtro
                  });
                },
                style: SegmentedButton.styleFrom(
                  foregroundColor: Colors.teal[800], // Cor do texto dos segmentos
                  selectedForegroundColor: Colors.white, // Cor do texto do segmento selecionado
                  selectedBackgroundColor: Colors.teal, // Cor de fundo do segmento selecionado
                  side: BorderSide(color: Colors.teal.shade200), // Borda dos segmentos
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 20), // Espaçamento após a barra de filtro

            const Text(
              'Meus Produtos na Despensa', // Título mais envolvente
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
                letterSpacing: 0.8, // Adiciona algum espaçamento entre as letras
              ),
            ),
            const SizedBox(height: 20), // Espaçamento aumentado
            Expanded(
              child: _filteredProdutos.isEmpty // Usa a lista filtrada aqui
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _searchController.text.isEmpty && _selectedFilter == ProductFilter.all
                          ? Icons.inbox_outlined // Ícone para "despensa vazia"
                          : Icons.search_off, // Ícone para "nenhum resultado"
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      _searchController.text.isEmpty && _selectedFilter == ProductFilter.all
                          ? 'Sua despensa está vazia! Adicione alguns produtos para começar.'
                          : 'Nenhum produto encontrado com "${_searchController.text}" para o filtro selecionado.',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _filteredProdutos.length, // Usa a lista filtrada aqui
                itemBuilder: (context, index) {
                  final produto = _filteredProdutos[index]; // Pega o produto da lista filtrada
                  Color? cardColor;
                  String statusText = '';
                  Color? statusTextColor;

                  if (produto.isExpired) {
                    cardColor = Colors.red[100]; // Vermelho mais claro para o fundo do cartão vencido
                    statusText = 'VENCIDO';
                    statusTextColor = Colors.red[800]; // Vermelho mais escuro para o texto de status
                  } else if (produto.pertoDoVencimento) {
                    cardColor = Colors.orange[100]; // Laranja mais claro
                    statusText = 'VENCE EM BREVE';
                    statusTextColor = Colors.orange[800]; // Laranja mais escuro
                  } else {
                    cardColor = Colors.white; // Padrão para itens não críticos
                  }

                  return Card(
                    color: cardColor,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0), // Ajusta o preenchimento
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal[200], // Fundo para o avatar da quantidade
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            produto.quantidade.toString(),
                            style: TextStyle(
                              color: Colors.teal[900], // Texto mais escuro para a quantidade
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        title: Text(
                          produto.nome,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18, // Título ligeiramente maior
                            color: Colors.teal[900],
                            decoration: produto.isExpired ? TextDecoration.lineThrough : null,
                            decorationThickness: 2, // Torna o risco mais visível
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4), // Espaçamento
                            Text(
                              'Validade: ${formatarData(produto.validade)}',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            if (statusText.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusTextColor,
                                    fontWeight: FontWeight.w800, // Torna o texto de status mais negrito
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.add_circle, color: Colors.teal[600], size: 30),
                              onPressed: () => adicionarUnidade(index),
                              tooltip: 'Adicionar 1 unidade',
                            ),
                            IconButton(
                              icon: Icon(Icons.remove_circle, color: Colors.red[600], size: 30),
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