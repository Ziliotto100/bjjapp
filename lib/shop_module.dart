// lib/shop_module.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

// --- TELA PRINCIPAL DA LOJA (COM CATEGORIAS) ---
class ShopPage extends StatefulWidget {
  final UserModel user;
  const ShopPage({super.key, required this.user});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> with TickerProviderStateMixin {
  late final TabController _tabController;
  final List<String> _categories = ['Todos', 'Gi', 'No-Gi', 'Lifestyle'];

  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildProductCardPlaceholder() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(color: Colors.white),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    width: double.infinity, height: 16, color: Colors.white),
                const SizedBox(height: 4),
                Container(width: 80, height: 20, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- NOVO WIDGET: BARRA DE PESQUISA INTEGRADA ---
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar produtos...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isManager = widget.user.role == UserRole.manager;
    final priceFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    // --- CORREÇÃO: REMOVIDO O SCAFFOLD E APPBAR DAQUI ---
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // --- BARRA DE PESQUISA E ABAS AGORA FAZEM PARTE DO CORPO ---
          _buildSearchBar(),
          Container(
            color: darkSurface,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: _categories.map((String category) {
                return Tab(text: category);
              }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('academies')
                  .doc(widget.user.academyId)
                  .collection('products')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Shimmer.fromColors(
                    baseColor: darkSurface,
                    highlightColor: darkScaffoldBackground,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.70,
                      ),
                      itemCount: 6,
                      itemBuilder: (context, index) =>
                          _buildProductCardPlaceholder(),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return const EmptyStateWidget(
                    icon: Icons.error_outline,
                    title: 'Erro ao Carregar',
                    message: 'Não foi possível buscar os produtos.',
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Loja Vazia',
                    message: 'Nenhum produto foi cadastrado ainda.',
                  );
                }

                final allProducts = snapshot.data!.docs
                    .map((doc) => Product.fromFirestore(doc))
                    .toList();

                final searchedProducts = _searchQuery.isEmpty
                    ? allProducts
                    : allProducts.where((p) {
                        final query = _searchQuery.toLowerCase();
                        return p.name.toLowerCase().contains(query) ||
                            p.category.toLowerCase().contains(query);
                      }).toList();

                final featuredProducts =
                    searchedProducts.where((p) => p.isFeatured).toList();

                return TabBarView(
                  controller: _tabController,
                  children: _categories.map((category) {
                    final filteredProducts = category == 'Todos'
                        ? searchedProducts
                        : searchedProducts
                            .where((p) =>
                                p.category.toLowerCase() ==
                                category.toLowerCase())
                            .toList();

                    if (filteredProducts.isEmpty) {
                      return EmptyStateWidget(
                        icon: Icons.search_off_rounded,
                        title: 'Nenhum Produto',
                        message: _searchQuery.isNotEmpty
                            ? 'Nenhum resultado para "$_searchQuery" nesta categoria.'
                            : 'Não há produtos nesta categoria.',
                      );
                    }

                    bool showCarousel =
                        category == 'Todos' && featuredProducts.isNotEmpty;

                    return AnimationLimiter(
                      child: CustomScrollView(
                        slivers: [
                          if (showCarousel)
                            SliverToBoxAdapter(
                              child: _FeaturedProductsCarousel(
                                user: widget.user,
                                featuredProducts: featuredProducts,
                                priceFormat: priceFormat,
                              ),
                            ),
                          SliverPadding(
                            padding: const EdgeInsets.all(12),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.70,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final product = filteredProducts[index];
                                  return AnimationConfiguration.staggeredGrid(
                                    position: index,
                                    duration: const Duration(milliseconds: 375),
                                    columnCount: 2,
                                    child: ScaleAnimation(
                                      child: FadeInAnimation(
                                        child: _ProductCard(
                                          product: product,
                                          user: widget.user,
                                          priceFormat: priceFormat,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                childCount: filteredProducts.length,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: isManager
          ? FloatingActionButton(
              heroTag: 'add_product_fab',
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => EditProductPage(
                          academyId: widget.user.academyId,
                        )));
              },
              tooltip: 'Adicionar Produto',
              child: const Icon(Icons.add_shopping_cart),
            )
          : null,
    );
  }
}

// --- WIDGET DO CARD DE PRODUTO (COM ANIMAÇÃO E NOVO LAYOUT) ---
class _ProductCard extends StatefulWidget {
  final Product product;
  final UserModel user;
  final NumberFormat priceFormat;

  const _ProductCard({
    required this.product,
    required this.user,
    required this.priceFormat,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final imageWidget = widget.product.imageUrls.isNotEmpty
        ? Image.network(
            widget.product.imageUrls.first,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.image_not_supported,
                size: 50,
                color: textHint),
          )
        : const Icon(Icons.image_not_supported, size: 50, color: textHint);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProductDetailPage(
            user: widget.user,
            product: widget.product,
          ),
        ));
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'product_image_${widget.product.id}_0',
                child: imageWidget,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          shadows: [
                            const Shadow(blurRadius: 1, color: Colors.black87)
                          ]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.priceFormat.format(widget.product.price),
                        style: const TextStyle(
                          color: primaryAccentForeground,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _ProductCardOverlays(product: widget.product),
            ],
          ),
        ),
      ),
    );
  }
}

// --- WIDGET DOS SELOS NO CARD ---
class _ProductCardOverlays extends StatelessWidget {
  final Product product;
  const _ProductCardOverlays({required this.product});

  @override
  Widget build(BuildContext context) {
    Widget? statusSelo;
    if (product.status == ProductStatus.esgotado) {
      statusSelo = _buildSelo('Esgotado', errorColor);
    } else if (product.status == ProductStatus.sobEncomenda) {
      statusSelo = _buildSelo('Sob Encomenda', infoColor);
    }

    Widget? infoSelo;
    if (product.isPromo) {
      infoSelo = _buildSelo('Promo', primaryAccent);
    } else if (product.isNew) {
      infoSelo = _buildSelo('Novo', successColor);
    }

    return Stack(
      children: [
        if (statusSelo != null)
          Positioned(
            top: 8,
            left: 8,
            child: statusSelo,
          ),
        if (infoSelo != null && statusSelo == null)
          Positioned(
            top: 8,
            left: 8,
            child: infoSelo,
          ),
      ],
    );
  }

  Widget _buildSelo(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}

// --- NOVO WIDGET: CARROSSEL DE PRODUTOS EM DESTAQUE ---
class _FeaturedProductsCarousel extends StatefulWidget {
  final List<Product> featuredProducts;
  final UserModel user;
  final NumberFormat priceFormat;

  const _FeaturedProductsCarousel({
    required this.featuredProducts,
    required this.user,
    required this.priceFormat,
  });

  @override
  State<_FeaturedProductsCarousel> createState() =>
      _FeaturedProductsCarouselState();
}

class _FeaturedProductsCarouselState extends State<_FeaturedProductsCarousel> {
  final _pageController = PageController(viewportFraction: 0.9);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Inicia o timer para auto-scroll se houver mais de um item
    if (widget.featuredProducts.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (_pageController.page == widget.featuredProducts.length - 1) {
          _pageController.animateToPage(0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut);
        } else {
          _pageController.nextPage(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.featuredProducts.length,
            itemBuilder: (context, index) {
              final product = widget.featuredProducts[index];
              return _FeaturedProductBanner(
                product: product,
                user: widget.user,
                priceFormat: widget.priceFormat,
              );
            },
          ),
        ),
        if (widget.featuredProducts.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
            child: SmoothPageIndicator(
              controller: _pageController,
              count: widget.featuredProducts.length,
              effect: const ExpandingDotsEffect(
                dotHeight: 8,
                dotWidth: 8,
                activeDotColor: primaryAccent,
                dotColor: textHint,
              ),
            ),
          ),
      ],
    );
  }
}

// --- WIDGET DO BANNER DE DESTAQUE (AGORA USADO NO CARROSSEL) ---
class _FeaturedProductBanner extends StatelessWidget {
  final Product product;
  final UserModel user;
  final NumberFormat priceFormat;

  const _FeaturedProductBanner({
    required this.product,
    required this.user,
    required this.priceFormat,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          user: user,
          product: product,
        ),
      )),
      child: Card(
        margin: const EdgeInsets.fromLTRB(6, 12, 6, 0),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (product.imageUrls.isNotEmpty)
                Image.network(
                  product.imageUrls.first,
                  fit: BoxFit.cover,
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      priceFormat.format(product.price),
                      style: const TextStyle(
                          color: primaryAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- TELA DE DETALHES DO PRODUTO (COM DESIGN REFINADO) ---
class ProductDetailPage extends StatefulWidget {
  final UserModel user;
  final Product product;

  const ProductDetailPage(
      {super.key, required this.user, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _currentImageIndex = 0;

  Future<void> _contactForPurchase(BuildContext context) async {
    final doc = await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.user.academyId)
        .get();
    final data = doc.data();
    final String? phoneNumber = data?['contactPhoneNumber'] as String?;

    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      showBjjSnackBar(context,
          'O telefone de contato da academia não foi configurado pelo gerente.',
          type: 'error');
      return;
    }

    String formattedPhoneNumber =
        phoneNumber.trim().replaceAll(RegExp(r'\D'), '');
    if (!formattedPhoneNumber.startsWith('55')) {
      formattedPhoneNumber = '55$formattedPhoneNumber';
    }

    final message = Uri.encodeComponent(
        'Olá! Tenho interesse no produto: ${widget.product.name}');
    final whatsappUrl =
        Uri.parse("https://wa.me/$formattedPhoneNumber?text=$message");

    try {
      bool launched =
          await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      if (!launched) {
        showBjjSnackBar(context, 'Não foi possível abrir o link do WhatsApp.',
            type: 'error');
      }
    } catch (e) {
      showBjjSnackBar(context, 'Ocorreu um erro ao tentar abrir o WhatsApp.',
          type: 'error');
    }
  }

  void _deleteProduct(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Produto?'),
        content: Text(
            'Tem certeza que deseja excluir "${widget.product.name}" permanentemente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('academies')
            .doc(widget.user.academyId)
            .collection('products')
            .doc(widget.product.id)
            .delete();
        Navigator.of(context).pop();
        showBjjSnackBar(context, 'Produto excluído com sucesso!',
            type: 'success');
      } catch (e) {
        showBjjSnackBar(context, 'Erro ao excluir produto.', type: 'error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isManager = widget.user.role == UserRole.manager;
    final priceFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300.0,
                pinned: true,
                stretch: true,
                title: Text(widget.product.name),
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  centerTitle: true,
                  title: Text(
                    widget.product.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
                    ),
                  ),
                  background: widget.product.imageUrls.isNotEmpty
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            PageView.builder(
                              onPageChanged: (index) {
                                setState(() {
                                  _currentImageIndex = index;
                                });
                              },
                              itemCount: widget.product.imageUrls.length,
                              itemBuilder: (context, index) {
                                final imageUrl =
                                    widget.product.imageUrls[index];
                                final heroTag =
                                    'product_image_${widget.product.id}_$index';
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => _ImageViewerPage(
                                          imageUrls: widget.product.imageUrls,
                                          initialIndex: index,
                                          heroTagPrefix:
                                              'product_image_${widget.product.id}',
                                        ),
                                      ),
                                    );
                                  },
                                  child: Hero(
                                    tag: heroTag,
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (widget.product.imageUrls.length > 1)
                              Positioned(
                                bottom: 10,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: widget.product.imageUrls.map((url) {
                                    int index =
                                        widget.product.imageUrls.indexOf(url);
                                    return Container(
                                      width: 8.0,
                                      height: 8.0,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 4.0),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _currentImageIndex == index
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.5),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        )
                      : Container(
                          color: darkSurface,
                          child: const Center(
                              child: Icon(Icons.image_not_supported,
                                  size: 80, color: textHint)),
                        ),
                ),
                actions: [
                  if (isManager)
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded),
                      tooltip: 'Editar Produto',
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => EditProductPage(
                            academyId: widget.user.academyId,
                            productToEdit: widget.product,
                          ),
                        ),
                      ),
                    ),
                  if (isManager)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: errorColor),
                      tooltip: 'Excluir Produto',
                      onPressed: () => _deleteProduct(context),
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        priceFormat.format(widget.product.price),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: primaryAccent,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          Chip(
                            avatar:
                                const Icon(Icons.category_outlined, size: 18),
                            label: Text(widget.product.category),
                          ),
                          Chip(
                            label: Text(
                                productStatusToString(widget.product.status)),
                            backgroundColor: widget.product.status ==
                                    ProductStatus.disponivel
                                ? successColor.withOpacity(0.8)
                                : (widget.product.status ==
                                        ProductStatus.esgotado
                                    ? errorColor.withOpacity(0.8)
                                    : infoColor.withOpacity(0.8)),
                            labelStyle: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      Text(
                        'Descrição',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.product.description.isEmpty
                            ? "Nenhuma descrição fornecida."
                            : widget.product.description,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(height: 1.5, color: textSecondary),
                      ),
                      const SizedBox(
                          height: 90), // Espaço para o botão flutuante
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'contact_fab',
        onPressed: widget.product.status == ProductStatus.esgotado
            ? null
            : () => _contactForPurchase(context),
        label: Text(widget.product.status == ProductStatus.esgotado
            ? 'Produto Esgotado'
            : 'Tenho Interesse'),
        icon: Icon(widget.product.status == ProductStatus.esgotado
            ? Icons.remove_shopping_cart_outlined
            : Icons.chat_rounded),
        backgroundColor: widget.product.status == ProductStatus.esgotado
            ? Colors.grey.shade700
            : successColor,
      ),
    );
  }
}

// --- TELA DE EDIÇÃO/CRIAÇÃO DE PRODUTO ---
class EditProductPage extends StatefulWidget {
  final String academyId;
  final Product? productToEdit;

  const EditProductPage(
      {super.key, required this.academyId, this.productToEdit});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String? _selectedCategory;
  ProductStatus _selectedStatus = ProductStatus.disponivel;
  bool _isFeatured = false;
  bool _isPromo = false;
  bool _isSaving = false;

  final List<XFile> _newImageFiles = [];
  final List<String> _existingImageUrls = [];

  bool get _isEditing => widget.productToEdit != null;
  final List<String> _categories = ['Gi', 'No-Gi', 'Lifestyle'];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.productToEdit!;
      _nameController.text = p.name;
      _descriptionController.text = p.description;
      _priceController.text = p.price.toString().replaceAll('.', ',');
      _selectedCategory = p.category;
      _isFeatured = p.isFeatured;
      _isPromo = p.isPromo;
      _selectedStatus = p.status;
      _existingImageUrls.addAll(p.imageUrls);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_existingImageUrls.length + _newImageFiles.length >= 3) {
      showBjjSnackBar(context, 'Você pode anexar no máximo 3 imagens.',
          type: 'info');
      return;
    }
    final picker = ImagePicker();
    final pickedFiles =
        await picker.pickMultiImage(imageQuality: 85, maxWidth: 1024);
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _newImageFiles.addAll(pickedFiles);
      });
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_existingImageUrls.isEmpty && _newImageFiles.isEmpty) {
      showBjjSnackBar(context, 'Adicione pelo menos uma imagem.',
          type: 'error');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final List<String> finalImageUrls = List.from(_existingImageUrls);

      for (final file in _newImageFiles) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final ref = FirebaseStorage.instance
            .ref()
            .child('product_images/${widget.academyId}/$fileName');
        await ref.putData(await file.readAsBytes());
        final imageUrl = await ref.getDownloadURL();
        finalImageUrls.add(imageUrl);
      }

      final productData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text.replaceAll(',', '.')),
        'category': _selectedCategory,
        'isFeatured': _isFeatured,
        'isPromo': _isPromo,
        'status': productStatusToString(_selectedStatus),
        'imageUrls': finalImageUrls,
        'createdAt': _isEditing
            ? widget.productToEdit!.createdAt
            : FieldValue.serverTimestamp(),
      };

      final collectionRef = FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('products');

      if (_isEditing) {
        await collectionRef.doc(widget.productToEdit!.id).update(productData);
      } else {
        await collectionRef.add(productData);
      }

      showBjjSnackBar(context, 'Produto salvo com sucesso!', type: 'success');
      Navigator.of(context).pop();
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao salvar o produto: $e', type: 'error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Produto' : 'Novo Produto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded),
            onPressed: _isSaving ? null : _saveProduct,
            tooltip: 'Salvar',
          )
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: _isSaving
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildImagePicker(),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        decoration:
                            const InputDecoration(labelText: 'Nome do Produto'),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Campo obrigatório'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                            labelText: 'Descrição', alignLabelWithHint: true),
                        maxLines: 4,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Campo obrigatório'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _priceController,
                        decoration:
                            const InputDecoration(labelText: 'Preço (R\$)'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Preço inválido';
                          final price = double.tryParse(v.replaceAll(',', '.'));
                          return (price == null || price <= 0)
                              ? 'Preço inválido'
                              : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration:
                            const InputDecoration(labelText: 'Categoria'),
                        items: _categories
                            .map((cat) =>
                                DropdownMenuItem(value: cat, child: Text(cat)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedCategory = value),
                        validator: (v) =>
                            v == null ? 'Selecione uma categoria' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<ProductStatus>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                            labelText: 'Status de Disponibilidade'),
                        items: ProductStatus.values
                            .map((status) => DropdownMenuItem(
                                value: status,
                                child: Text(productStatusToString(status))))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedStatus = value!),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Marcar como Destaque'),
                        value: _isFeatured,
                        onChanged: (val) => setState(() => _isFeatured = val),
                        secondary: const Icon(Icons.star_border_rounded),
                      ),
                      SwitchListTile(
                        title: const Text('Marcar como Promoção'),
                        value: _isPromo,
                        onChanged: (val) => setState(() => _isPromo = val),
                        secondary: const Icon(Icons.sell_outlined),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        const Text('Imagens do Produto (até 3)',
            style: TextStyle(color: textHint)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._existingImageUrls.map((url) => _buildImageThumbnail(url, null)),
            ..._newImageFiles.map((file) => _buildImageThumbnail(null, file)),
            if (_existingImageUrls.length + _newImageFiles.length < 3)
              _buildAddImageButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildImageThumbnail(String? imageUrl, XFile? imageFile) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: textHint),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: imageFile != null
                  ? FutureBuilder<Uint8List>(
                      future: imageFile.readAsBytes(),
                      builder: (BuildContext context,
                          AsyncSnapshot<Uint8List> snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
                            snapshot.hasData) {
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            width: 100,
                            height: 100,
                          );
                        } else {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                      },
                    )
                  : Image.network(imageUrl!,
                      fit: BoxFit.cover, width: 100, height: 100),
            ),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: IconButton(
              icon: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 16, color: Colors.white),
              ),
              onPressed: () {
                setState(() {
                  if (imageFile != null) {
                    _newImageFiles.remove(imageFile);
                  } else {
                    _existingImageUrls.remove(imageUrl);
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageButton() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(color: textHint, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.add_a_photo_outlined, color: textHint, size: 32),
        ),
      ),
    );
  }
}

// --- TELA PARA VISUALIZAR IMAGEM (MODIFICADA PARA GALERIA) ---
class _ImageViewerPage extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String heroTagPrefix;

  const _ImageViewerPage({
    required this.imageUrls,
    required this.initialIndex,
    required this.heroTagPrefix,
  });

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.imageUrls.length,
          itemBuilder: (context, index) {
            final imageUrl = widget.imageUrls[index];
            final heroTag = '${widget.heroTagPrefix}_$index';
            return Hero(
              tag: heroTag,
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 1.0,
                maxScale: 4.0,
                child: Image.network(imageUrl),
              ),
            );
          },
        ),
      ),
    );
  }
}
