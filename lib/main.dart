import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // Necessário para codificação/decodificação JSON

void main() => runApp(const MyApp());

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

  final TextEditingController nomeController = TextEditingController();
  final TextEditingController validadeController = TextEditingController();
  final TextEditingController quantidadeController = TextEditingController();

  // Inicializa SharedPreferences
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

  // Carrega produtos do SharedPreferences
  void _loadProdutos() {
    final String? produtosJsonString = _prefs.getString('produtos_list');
    if (produtosJsonString != null) {
      final List<dynamic> jsonList = json.decode(produtosJsonString);
      setState(() {
        produtos = jsonList.map((jsonItem) => Produto.fromJson(jsonItem)).toList();
        // Ordena os produtos: vencidos primeiro, depois perto do vencimento, depois por data de validade
        _sortProdutos();
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
    });

    nomeController.clear();
    validadeController.clear();
    quantidadeController.clear();
    _showSnackBar('Produto "$nome" adicionado com sucesso!', backgroundColor: Colors.green[700]);
  }

  void darBaixaProduto(int index) {
    final String productName = produtos[index].nome;
    setState(() {
      if (produtos[index].quantidade > 1) {
        produtos[index].quantidade--;
        _showSnackBar('Uma unidade de "$productName" foi removida.');
      } else {
        produtos.removeAt(index);
        _showSnackBar('"$productName" foi removido da despensa.',
            action: SnackBarAction(
              label: 'Desfazer',
              onPressed: () {
                setState(() {
                  // Isso é um "desfazer" básico. Para um "desfazer" mais complexo, armazene o produto removido.
                  _loadProdutos(); // Recarrega para reverter se necessário.
                });
              },
            ));
      }
      _sortProdutos(); // Ordena após a modificação
      _saveProdutos(); // Salva após a alteração da quantidade
    });
  }

  void adicionarUnidade(int index) {
    setState(() {
      produtos[index].quantidade++;
      _sortProdutos(); // Ordena após a modificação
      _saveProdutos(); // Salva após a alteração da quantidade
      _showSnackBar('Uma unidade de "${produtos[index].nome}" foi adicionada.');
    });
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
            // Campos de entrada
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
              child: produtos.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined, // Ícone de estado vazio
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Sua despensa está vazia! Adicione alguns produtos para começar.',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: produtos.length,
                itemBuilder: (context, index) {
                  final produto = produtos[index];
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