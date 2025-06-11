import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'add_task_screen.dart';
import 'edit_task_screen.dart';

class FirestoreDataScreen extends StatefulWidget {
  const FirestoreDataScreen({super.key});

  @override
  State<FirestoreDataScreen> createState() => _FirestoreDataScreenState();
}

class _FirestoreDataScreenState extends State<FirestoreDataScreen> {
  String _sortLabel   = 'Waga ↓';
  String _filterLabel = 'Do zrobienia';

  final Map<String, Map<String, dynamic>> _sortOptions = {
    'Waga ↓':   {'field': 'waga',   'desc': true},
    'Waga ↑':   {'field': 'waga',   'desc': false},
    'Termin ↓': {'field': 'termin','desc': true},
    'Termin ↑': {'field': 'termin','desc': false},
  };
  final Map<String, bool> _filterOptions = {
    'Do zrobienia': false,
    'Zrobione':     true,
  };

  @override
  Widget build(BuildContext context) {
    final sortCfg     = _sortOptions[_sortLabel]!;
    final filterValue = _filterOptions[_filterLabel]!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Icon(Icons.auto_awesome, size: 28, color: Colors.white),
        ),
        title: Text(
          'TaskWizard',
          style: GoogleFonts.orbitron(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.1,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF07071E), Color(0xFF2121A1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: _buildTasksList(context, sortCfg, filterValue),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add'),
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 6,
        child: const Icon(Icons.add, size: 32, color: Colors.white),
      ),
      bottomNavigationBar: SizedBox(
        height: 70,
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF2A0055),
          selectedItemColor: const Color(0xFFFFD369),
          unselectedItemColor: Colors.white70,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          onTap: (i) {
            if (i == 0) {
              _showSortSheet();
            } else if (i == 1) {
              _showFilterSheet();
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.sort),
              label: 'Sortuj',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.filter_list),
              label: 'Status',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksList(
      BuildContext ctx,
      Map<String, dynamic> sortCfg,
      bool filterValue,
  ) {
    // Dynamically adjust the header based on status
    final headerText = filterValue
        ? 'ZADANIA ZROBIONE:'
        : 'ZADANIA DO ZROBIENIA:';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headerText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc('demo_users')
                .collection('tasks')
                .where('zrobione', isEqualTo: filterValue)
                .orderBy(sortCfg['field'], descending: sortCfg['desc'])
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                );
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Center(
                  child: Text('Brak zadań.', style: TextStyle(color: Colors.white70)),
                );
              }
              final tasks = snap.data!.docs;
              return ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (c, i) {
                  final doc = tasks[i];
                  final data = doc.data()! as Map<String, dynamic>;

                  final name = data['Nazwa'] ?? '';
                  final desc = data['Opis'] ?? '';

                  // Priorytet
                  final rawWaga = data['waga'];
                  final waga = rawWaga is int
                      ? rawWaga
                      : int.tryParse(rawWaga.toString()) ?? 1;
                  final wagaOpis = {
                    5: 'Bardzo ważne',
                    4: 'Ważne',
                    3: 'Średnie',
                    2: 'Mało ważne',
                    1: 'Znikomy priorytet',
                  }[waga]!;

                  // Termin
                  final termin = data['termin'] != null
                      ? (data['termin'] as Timestamp)
                          .toDate()
                          .toLocal()
                          .toString()
                          .split(' ')[0]
                      : '-';

                  // Czas trwania
                  final rawDur = data['czas_trwania'];
                  final totalMin = rawDur is int
                      ? rawDur
                      : int.tryParse(rawDur.toString()) ?? 0;
                  final h = totalMin ~/ 60;
                  final m = totalMin % 60;
                  final durText = h > 0
                      ? '${h}h${m > 0 ? ' ${m}min' : ''}'
                      : '${m}min';

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        '$termin | $durText | $wagaOpis',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      trailing:
                          const Icon(Icons.expand_more, color: Colors.white70),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(desc,
                                    style:
                                        const TextStyle(color: Colors.white)),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.white70),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditTaskScreen(
                                        taskId: doc.id,
                                        taskData: data,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A0055),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sortuj według:',
                style: GoogleFonts.orbitron(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortLabel,
                dropdownColor: const Color(0xFF2A0055),
                iconEnabledColor: Colors.white,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                items: _sortOptions.keys.map((lbl) {
                  return DropdownMenuItem(
                    value: lbl,
                    child: Text(lbl),
                  );
                }).toList(),
                onChanged: (lbl) => setState(() => _sortLabel = lbl!),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zamknij', style: TextStyle(color: Colors.white70)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A0055),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filtruj status:',
                style: GoogleFonts.orbitron(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: _filterOptions.keys.map((lbl) {
                final selected = lbl == _filterLabel;
                return ChoiceChip(
                  label: Text(lbl),
                  selected: selected,
                  onSelected: (_) => setState(() => _filterLabel = lbl),
                  selectedColor: const Color(0xFFFFD369),
                  backgroundColor: const Color(0xFF2A0055),
                  labelStyle:
                      TextStyle(color: selected ? Colors.black : Colors.white),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zamknij', style: TextStyle(color: Colors.white70)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
