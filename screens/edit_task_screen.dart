import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_openai/dart_openai.dart';

class EditTaskScreen extends StatefulWidget {
  final String taskId;
  final Map<String, dynamic> taskData;

  const EditTaskScreen({
    super.key,
    required this.taskId,
    required this.taskData,
  });

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtl;
  late TextEditingController _descCtl;
  late TextEditingController _hoursCtl;
  late TextEditingController _minutesCtl;
  DateTime? _selectedDate;
  int _selectedWaga = 3;
  bool _zrobione   = false;

  bool _isLoadingAI = false;
  String? _aiError;

  final openAI = OpenAI.instance;

  @override
  void initState() {
    super.initState();
    final data = widget.taskData;
    _nameCtl      = TextEditingController(text: data['Nazwa'] ?? '');
    _descCtl      = TextEditingController(text: data['Opis'] ?? '');
    _selectedDate = (data['termin'] as Timestamp).toDate();
    final dur     = data['czas_trwania'];
    final totalMin = dur is int ? dur : int.parse(dur.toString());
    _hoursCtl     = TextEditingController(text: (totalMin ~/ 60).toString());
    _minutesCtl   = TextEditingController(text: (totalMin % 60).toString());
    final w       = data['waga'];
    _selectedWaga = w is int ? w : int.parse(w.toString());
    _zrobione    = data['zrobione'] as bool? ?? false;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    _hoursCtl.dispose();
    _minutesCtl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  Future<void> _askWizardAI() async {
    final descCtl = TextEditingController(text: _descCtl.text);
    DateTime? wizDate = _selectedDate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          left: 16, right: 16, top: 16,
        ),
        child: StatefulBuilder(
          builder: (ctx2, setState2) {
            Future<void> pickDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: ctx2,
                initialDate: wizDate ?? now,
                firstDate: now,
                lastDate: DateTime(now.year + 5),
              );
              if (picked != null) setState2(() => wizDate = picked);
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: descCtl,
                  decoration: const InputDecoration(labelText: 'Opis dla AI'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Data:'),
                    const SizedBox(width: 12),
                    Text(
                      wizDate != null
                          ? wizDate!.toLocal().toString().split(' ')[0]
                          : 'nie wybrano',
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(onPressed: pickDate, child: const Text('Wybierz datę')),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: _isLoadingAI
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: const Text('Generuj z AI'),
                  onPressed: (_isLoadingAI || wizDate == null || descCtl.text.trim().isEmpty)
                      ? null
                      : () async {
                          Navigator.pop(ctx2);
                          setState(() {
                            _isLoadingAI = true;
                            _aiError = null;
                          });
                          final messenger = ScaffoldMessenger.of(context);

                          final prompt = '''
Aktualne zadanie:
Nazwa: "${_nameCtl.text}"
Opis (kontekst): "${descCtl.text.trim()}"
Data: ${wizDate!.toLocal().toString().split(' ')[0]}

Wygeneruj **dokładnie jedną linię** w formacie:
NazwaZadania;Waga;Czas_w_minutach;OpisZadania

- Waga: tylko cyfra 1–5
- Czas: tylko cyfra minut
- Opis: krótki
Przykład:
Projekt Flutter;4;120;Zrobienie aplikacji przy użyciu Flutter
''';

                          try {
                            final c = await openAI.completion.create(
                              model: "gpt-3.5-turbo-instruct",
                              prompt: prompt,
                              maxTokens: 80,
                            );
                            final line = c.choices.first.text.trim();
                            final parts = line.split(';');
                            if (parts.length != 4) {
                              throw FormatException('Niepoprawny format AI: $line');
                            }

                            final nameRaw     = parts[0].trim();
                            final weightRaw   = parts[1].trim().replaceAll(RegExp(r'\D'), '');
                            final durationRaw = parts[2].trim().replaceAll(RegExp(r'\D'), '');
                            final descRaw     = parts[3].trim();

                            final weight   = int.tryParse(weightRaw) ?? _selectedWaga;
                            final duration = int.tryParse(durationRaw) ?? 0;

                            if (!mounted) return;
                            setState(() {
                              _nameCtl.text    = nameRaw;
                              _selectedWaga    = weight.clamp(1, 5);
                              _hoursCtl.text   = (duration ~/ 60).toString();
                              _minutesCtl.text = (duration % 60).toString();
                              _descCtl.text    = descRaw;
                            });
                          } catch (e) {
                            if (mounted) messenger.showSnackBar(
                              SnackBar(content: Text('Błąd AI: $e')),
                            );
                          } finally {
                            if (mounted) setState(() => _isLoadingAI = false);
                          }
                        },
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _updateTask() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uzupełnij formularz i wybierz datę')),
      );
      return;
    }
    final hours    = int.tryParse(_hoursCtl.text) ?? 0;
    final minutes  = int.tryParse(_minutesCtl.text) ?? 0;
    final duration = hours * 60 + minutes;

    final newData = {
      'Nazwa':        _nameCtl.text,
      'Opis':         _descCtl.text,
      'waga':         _selectedWaga,
      'termin':       Timestamp.fromDate(_selectedDate!),
      'czas_trwania': duration,
      'zrobione':     _zrobione,
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc('demo_users')
          .collection('tasks')
          .doc(widget.taskId)
          .update(newData);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Błąd aktualizacji: $e')));
    }
  }

  Future<void> _deleteTask() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usuń zadanie?'),
        content: const Text('Czy na pewno chcesz usunąć to zadanie?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
          TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Usuń')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc('demo_users')
          .collection('tasks')
          .doc(widget.taskId)
          .delete();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Błąd usuwania: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edytuj zadanie')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Wizard AI button
              ElevatedButton.icon(
                icon: _isLoadingAI
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: const Text('Wizard AI'),
                onPressed: _askWizardAI,
              ),
              const SizedBox(height: 12),
              // Standardowy formularz
              TextFormField(
                controller: _nameCtl,
                decoration: const InputDecoration(labelText: 'Nazwa'),
                validator: (v) => v?.isEmpty == true ? 'Wymagana nazwa' : null,
              ),
              TextFormField(
                controller: _descCtl,
                decoration: const InputDecoration(labelText: 'Opis'),
                validator: (v) => v?.isEmpty == true ? 'Wymagany opis' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Waga: '), const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _selectedWaga,
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('Bardzo ważne')),
                    DropdownMenuItem(value: 4, child: Text('Ważne')),
                    DropdownMenuItem(value: 3, child: Text('Średnie')),
                    DropdownMenuItem(value: 2, child: Text('Mało ważne')),
                    DropdownMenuItem(value: 1, child: Text('Znikomy priorytet')),
                  ],
                  onChanged: (v) => setState(() => _selectedWaga = v!),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Termin: '), const SizedBox(width: 12),
                Text(
                  _selectedDate != null
                      ? _selectedDate!.toLocal().toString().split(' ')[0]
                      : 'nie wybrano',
                ),
                const SizedBox(width: 12),
                ElevatedButton(onPressed: _selectDate, child: const Text('Wybierz datę')),
              ]),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Zrobione'),
                value: _zrobione,
                onChanged: (v) => setState(() => _zrobione = v!),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Flexible(
                  child: TextFormField(
                    controller: _hoursCtl,
                    decoration: const InputDecoration(labelText: 'Godziny'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v?.isEmpty == true ? '0' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: TextFormField(
                    controller: _minutesCtl,
                    decoration: const InputDecoration(labelText: 'Minuty'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v?.isEmpty == true ? '0' : null,
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _updateTask, child: const Text('Zapisz zmiany')),
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('Usuń zadanie', style: TextStyle(color: Colors.red)),
                onPressed: _deleteTask,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
