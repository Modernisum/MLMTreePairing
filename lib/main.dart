import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Binary MLM Tree',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text("Binary MLM Tree")),
        body: const TreeViewer(),
      ),
    );
  }
}

class UserNode {
  final String id;
  String name;
  String? email;
  String? phone;
  UserNode? left;
  UserNode? right;
  bool isExpanded;
  final GlobalKey key = GlobalKey();

  UserNode({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.left,
    this.right,
    this.isExpanded = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'isExpanded': isExpanded,
      'left': left?.toJson(),
      'right': right?.toJson(),
    };
  }

  static UserNode fromJson(Map<String, dynamic> json) {
    return UserNode(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      isExpanded: json['isExpanded'] ?? true,
      left: json['left'] != null ? fromJson(json['left']) : null,
      right: json['right'] != null ? fromJson(json['right']) : null,
    );
  }
}

String generateMLMUserId() {
  final random = Random();
  final number = 10000000 + random.nextInt(90000000);
  return 'm$number';
}

class TreeViewer extends StatefulWidget {
  const TreeViewer({super.key});

  @override
  State<TreeViewer> createState() => _TreeViewerState();
}

class _TreeViewerState extends State<TreeViewer> {
  late UserNode root;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTree();
  }

  Future<void> _saveTree() async {
    await FirebaseFirestore.instance.collection('mlm_tree').doc('root').set(
          root.toJson(),
        );
  }

  Future<void> _loadTree() async {
    final doc = await FirebaseFirestore.instance
        .collection('mlm_tree')
        .doc('root')
        .get();
    if (doc.exists) {
      setState(() {
        root = UserNode.fromJson(doc.data()!);
        _isLoading = false;
      });
    } else {
      root = UserNode(
        id: generateMLMUserId(),
        name: 'Admin',
        email: 'admin@example.com',
        phone: '1234567890',
      );
      await _saveTree();
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _searchAndScroll(String id) {
    final match = _findNodeAndExpand(root, id);
    if (match != null) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = match.key.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(seconds: 1),
            alignment: 0.5,
          );
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User ID not found")),
      );
    }
  }

  UserNode? _findNodeAndExpand(UserNode? node, String id) {
    if (node == null) return null;
    if (node.id == id) return node;

    final left = _findNodeAndExpand(node.left, id);
    if (left != null) {
      node.isExpanded = true;
      return left;
    }

    final right = _findNodeAndExpand(node.right, id);
    if (right != null) {
      node.isExpanded = true;
      return right;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search ID (e.g., m12345678)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _searchAndScroll(_searchController.text),
                child: const Text("Search"),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saveTree,
                child: const Text("Save Tree"),
              )
            ],
          ),
        ),
        Expanded(
          child: InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(1000),
            minScale: 0.2,
            maxScale: 2.5,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: BinaryTreeWidget(node: root, onTreeChanged: _saveTree),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class BinaryTreeWidget extends StatefulWidget {
  final UserNode node;
  final VoidCallback onTreeChanged;
  const BinaryTreeWidget(
      {super.key, required this.node, required this.onTreeChanged});

  @override
  State<BinaryTreeWidget> createState() => _BinaryTreeWidgetState();
}

class _BinaryTreeWidgetState extends State<BinaryTreeWidget> {
  @override
  Widget build(BuildContext context) {
    return _buildNode(widget.node);
  }

  Widget _buildNode(UserNode? node) {
    if (node == null) return const SizedBox();

    return Column(
      key: node.key,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _showEditDialog(node),
          child: Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.lightBlue.shade50,
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4)
              ],
            ),
            child: Column(
              children: [
                Text(node.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("ID: ${node.id}",
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
                if (node.email != null)
                  Text(node.email!, style: const TextStyle(fontSize: 12)),
                if (node.phone != null)
                  Text(node.phone!, style: const TextStyle(fontSize: 12)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (node.left == null)
                      IconButton(
                        icon: const Icon(Icons.person_add_alt_1),
                        tooltip: "Add Left",
                        onPressed: () => _addChild(node, isLeft: true),
                      ),
                    if (node.right == null)
                      IconButton(
                        icon: const Icon(Icons.person_add),
                        tooltip: "Add Right",
                        onPressed: () => _addChild(node, isLeft: false),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (node.isExpanded && (node.left != null || node.right != null))
          Column(
            children: [
              const SizedBox(height: 100),
              CustomPaint(
                painter: LinePainter(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (node.left != null)
                      Flexible(
                          fit: FlexFit.loose, child: _buildNode(node.left)),
                    const SizedBox(width: 40),
                    if (node.right != null)
                      Flexible(
                          fit: FlexFit.loose, child: _buildNode(node.right)),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _addChild(UserNode parent, {required bool isLeft}) {
    final newNode = UserNode(
      id: generateMLMUserId(),
      name: "New Customer",
    );

    setState(() {
      if (isLeft) {
        parent.left = newNode;
      } else {
        parent.right = newNode;
      }
      parent.isExpanded = true;
    });

    widget.onTreeChanged();
  }

  void _showEditDialog(UserNode node) {
    final nameController = TextEditingController(text: node.name);
    final emailController = TextEditingController(text: node.email);
    final phoneController = TextEditingController(text: node.phone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Customer"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("ID: ${node.id}",
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name")),
            TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "Email")),
            TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "Phone")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              setState(() {
                node.name = nameController.text.trim();
                node.email = emailController.text;
                node.phone = phoneController.text;
              });
              Navigator.pop(context);
              widget.onTreeChanged();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}

class LinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 2;

    final centerTop = Offset(size.width / 2, 0);
    final verticalMid = Offset(size.width / 2, 40);

    final leftPoint = Offset(size.width / 4, 40);
    final rightPoint = Offset(size.width * 3 / 4, 40);

    canvas.drawLine(centerTop, verticalMid, paint);
    canvas.drawLine(verticalMid, leftPoint, paint);
    canvas.drawLine(verticalMid, rightPoint, paint);
    canvas.drawLine(leftPoint, Offset(leftPoint.dx, leftPoint.dy + 20), paint);
    canvas.drawLine(
        rightPoint, Offset(rightPoint.dx, rightPoint.dy + 20), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
