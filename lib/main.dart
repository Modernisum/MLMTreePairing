import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

final GlobalKey globalTreeKey = GlobalKey();

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
      home: LayoutBuilder(
        builder: (context, constraints) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("Binary MLM Tree"),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () async {
                    final id = await showDialog<String>(
                      context: context,
                      builder: (context) {
                        final controller = TextEditingController();
                        return AlertDialog(
                          title: const Text("Search by ID"),
                          content: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                                labelText: "Enter ID (e.g. M12345678)"),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(context, controller.text),
                              child: const Text("Search"),
                            )
                          ],
                        );
                      },
                    );

                    if (id != null && id.isNotEmpty) {
                      try {
                        final doc = await FirebaseFirestore.instance
                            .collection("mlm_tree")
                            .doc("root")
                            .get();
                        if (doc.exists) {
                          final data = doc.data();
                          if (data != null) {
                            final UserNode rootNode = UserNode.fromJson(data);
                            final foundNode = _findNodeById(rootNode, id);
                            if (foundNode != null) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text("User Found"),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text("ID:  ${foundNode.id}"),
                                      Text("Name:  ${foundNode.name}"),
                                      if (foundNode.email != null)
                                        Text("Email: ${foundNode.email}"),
                                      if (foundNode.phone != null)
                                        Text("Phone: ${foundNode.phone}"),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("Close"),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _confirmDelete(context, foundNode.id);
                                      },
                                      child: const Text("Delete Node",
                                          style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              _showNotFound(context);
                            }
                          } else {
                            _showNotFound(context);
                          }
                        } else {
                          _showNotFound(context);
                        }
                      } catch (e) {
                        debugPrint("Firebase exception: \$e");
                        _showNotFound(context);
                      }
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: () async {
                    final boundary = globalTreeKey.currentContext
                        ?.findRenderObject() as RenderRepaintBoundary?;
                    if (boundary != null) {
                      final image = await boundary.toImage(pixelRatio: 3.0);
                      final byteData = await image.toByteData(
                          format: ui.ImageByteFormat.png);
                      final pngBytes = byteData!.buffer.asUint8List();

                      final pdf = pw.Document();
                      final imageProvider = pw.MemoryImage(pngBytes);

                      pdf.addPage(
                        pw.Page(
                          build: (pw.Context context) {
                            return pw.Center(child: pw.Image(imageProvider));
                          },
                        ),
                      );

                      await Printing.sharePdf(
                          bytes: await pdf.save(), filename: 'mlm_tree.pdf');
                    }
                  },
                )
              ],
            ),
            body: SizedBox(
              height: constraints.maxHeight,
              child: TreeViewer(),
            ),
          );
        },
      ),
    );
  }

  UserNode? _findNodeById(UserNode node, String id) {
    if (node.id == id) return node;
    UserNode? found;
    if (node.left != null) found = _findNodeById(node.left!, id);
    if (found != null) return found;
    if (node.right != null) found = _findNodeById(node.right!, id);
    return found;
  }

  void _confirmDelete(BuildContext context, String idToDelete) async {
    final doc = await FirebaseFirestore.instance
        .collection("mlm_tree")
        .doc("root")
        .get();
    if (!doc.exists) return;

    final data = doc.data();
    if (data == null) return;

    final rootNode = UserNode.fromJson(data);
    final updated = _deleteNode(rootNode, idToDelete);

    if (updated != null) {
      await FirebaseFirestore.instance
          .collection("mlm_tree")
          .doc("root")
          .set(updated.toJson());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Node deleted successfully.")),
      );
    }
  }

  UserNode? _deleteNode(UserNode? node, String idToDelete) {
    if (node == null) return null;
    if (node.left?.id == idToDelete) {
      node.left = null;
      return node;
    }
    if (node.right?.id == idToDelete) {
      node.right = null;
      return node;
    }
    _deleteNode(node.left, idToDelete);
    _deleteNode(node.right, idToDelete);
    return node;
  }

  void _showNotFound(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("User Not Found"),
        content: const Text("No user found with the provided ID."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
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
  return 'M$number';
}

class TreeViewer extends StatefulWidget {
  const TreeViewer({super.key});

  @override
  State<TreeViewer> createState() => _TreeViewerState();
}

class _TreeViewerState extends State<TreeViewer> {
  late UserNode root;
  bool _isLoading = true;

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
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

//
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

  void _addChildAuto(UserNode parent) {
    final newNode = UserNode(
      id: generateMLMUserId(),
      name: "New Customer",
    );

    setState(() {
      if (parent.left == null) {
        parent.left = newNode;
      } else {
        parent.right ??= newNode;
      }
      parent.isExpanded = true;
    });

    widget.onTreeChanged();
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
                    if (node.left == null || node.right == null)
                      IconButton(
                        icon: const Icon(Icons.person_add),
                        tooltip: "Add Customer",
                        onPressed: () => _addChildAuto(node),
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

    // Reduce vertical space
    final verticalSpace = 0.0; // was 40
    final downLine = 10.0; // was 20

    final centerTop = Offset(size.width / 2, 0);
    final verticalMid = Offset(size.width / 2, verticalSpace);

    final leftPoint = Offset(size.width / 4, verticalSpace);
    final rightPoint = Offset(size.width * 3 / 4, verticalSpace);

    canvas.drawLine(centerTop, verticalMid, paint);
    canvas.drawLine(verticalMid, leftPoint, paint);
    canvas.drawLine(verticalMid, rightPoint, paint);
    canvas.drawLine(
        leftPoint, Offset(leftPoint.dx, leftPoint.dy + downLine), paint);
    canvas.drawLine(
        rightPoint, Offset(rightPoint.dx, rightPoint.dy + downLine), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
