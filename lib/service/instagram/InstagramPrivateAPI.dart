import 'package:flutter/material.dart';

import '../../Screen/instagram/instagram_screen.dart';

class InstagramMessagesApp extends StatefulWidget {
  @override
  _InstagramMessagesAppState createState() => _InstagramMessagesAppState();
}

class _InstagramMessagesAppState extends State<InstagramMessagesApp> {
  final InstagramPrivateAPI api = InstagramPrivateAPI();
  List<dynamic> conversations = [];
  bool isLoggedIn = false;
  bool isLoading = false;

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // تسجيل الدخول
  Future<void> loginToInstagram() async {
    setState(() => isLoading = true);

    bool success = await api.login(
      usernameController.text,
      passwordController.text,
    );

    setState(() {
      isLoading = false;
      isLoggedIn = success;
    });

    if (success) {
      loadConversations();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم تسجيل الدخول بنجاح')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ فشل تسجيل الدخول')),
      );
    }
  }

  // جلب المحادثات
  Future<void> loadConversations() async {
    setState(() => isLoading = true);

    var threads = await api.getInbox();

    setState(() {
      conversations = threads;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Instagram Messages'),
        backgroundColor: Colors.purple,
      ),
      body: !isLoggedIn ? _buildLoginScreen() : _buildMessagesScreen(),
    );
  }

  // شاشة تسجيل الدخول
  Widget _buildLoginScreen() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock, size: 80, color: Colors.purple),
          SizedBox(height: 30),
          TextField(
            controller: usernameController,
            decoration: InputDecoration(
              labelText: 'اسم المستخدم',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          SizedBox(height: 15),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.password),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: isLoading ? null : loginToInstagram,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              minimumSize: Size(double.infinity, 50),
            ),
            child: isLoading
                ? CircularProgressIndicator(color: Colors.white)
                : Text('تسجيل الدخول', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  // شاشة المحادثات
  Widget _buildMessagesScreen() {
    return RefreshIndicator(
      onRefresh: loadConversations,
      child: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          var thread = conversations[index];
          var users = thread['users'] ?? [];
          var lastMessage = thread['last_permanent_item'];

          String username = users.isNotEmpty
              ? users[0]['username'] ?? 'مستخدم'
              : 'مستخدم';

          String lastText = '';
          if (lastMessage != null) {
            if (lastMessage['item_type'] == 'text') {
              lastText = lastMessage['text'] ?? '';
            } else {
              lastText = '[${lastMessage['item_type']}]';
            }
          }

          return ListTile(
            leading: CircleAvatar(
              backgroundImage: users.isNotEmpty && users[0]['profile_pic_url'] != null
                  ? NetworkImage(users[0]['profile_pic_url'])
                  : null,
              child: users.isEmpty ? Icon(Icons.person) : null,
            ),
            title: Text(username, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(lastText, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    api: api,
                    threadId: thread['thread_id'],
                    username: username,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// شاشة المحادثة الفردية
class ChatScreen extends StatefulWidget {
  final InstagramPrivateAPI api;
  final String threadId;
  final String username;

  ChatScreen({required this.api, required this.threadId, required this.username});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<dynamic> messages = [];
  TextEditingController messageController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadMessages();
  }

  Future<void> loadMessages() async {
    setState(() => isLoading = true);
    var msgs = await widget.api.getThreadMessages(widget.threadId);
    setState(() {
      messages = msgs.reversed.toList();
      isLoading = false;
    });
  }

  Future<void> sendMessage() async {
    if (messageController.text.isEmpty) return;

    String text = messageController.text;
    messageController.clear();

    bool sent = await widget.api.sendMessage(widget.threadId, text);

    if (sent) {
      loadMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.username),
        backgroundColor: Colors.purple,
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                var msg = messages[index];
                bool isMe = msg['user_id'].toString() == widget.api.userId;

                String text = '';
                if (msg['item_type'] == 'text') {
                  text = msg['text'] ?? '';
                } else {
                  text = '[${msg['item_type']}]';
                }

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.purple[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(text),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالة...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: sendMessage,
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