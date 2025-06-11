import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_openai/dart_openai.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});
  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl    = TextEditingController();
  final _descCtl    = TextEditingController();
  final _hoursCtl   = TextEditingController();
  final _minutesCtl = TextEditingController();
  DateTime? _selectedDate;
  int _selectedWaga = 3;

  bool _isLoadingAI = false;
  String? _aiError;

  final openAI = OpenAI.instance;

  @override
  void initState() {
    super.initState();
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

  Future<void> _askWizardAI(String desc, DateTime date) async {
    setState(() {
      _isLoadingAI = true;
      _aiError = null;
    });
    final messenger = ScaffoldMessenger.of(context);

    final prompt = '''
Masz zadanie: opis dotyczy **samego zadania** – nie innych tematów.
Opis zadania: "$desc"
Data wykonania: ${date.toLocal().toString().split(' ')[0]}

Wygeneruj **tylko jedną linię** w dokładnym formacie:
NazwaZadania;Waga;Czas_w_minutach;OpisZadania

gdzie:
- Waga to liczba 1–5 (5 = najwyższy priorytet),
- Czas to łączny czas w minutach,
- Opis to krótki opis zadania.

Przykład odpowiedzi:
Projekt Flutter;4;120;Zrobienie aplikacji przy użyciu Flutter
''';

    try {
      final completion = await openAI.completion.create(
        model: "gpt-3.5-turbo-instruct",
        prompt: prompt,
        maxTokens: 80,
      );
      final text = completion.choices.first.text.trim();
      final parts = text.split(';');
      if (parts.length != 4) {
        throw FormatException('Niepoprawny format: $text');
      }

      final name     = parts[0].trim();
      final weight   = int.parse(parts[1].trim());
      final duration = int.parse(parts[2].trim());
      final taskDesc = parts[3].trim();

      await FirebaseFirestore.instance
          .collection('users')
          .doc('demo_users')
          .collection('tasks')
          .add({
        'Nazwa':        name,
        'Opis':         taskDesc,
        'waga':         weight,
        'termin':       Timestamp.fromDate(date),
        'czas_trwania': duration,
        'zrobione':     false,
      });

      if (mounted) Navigator.of(context).pop(); // wróć do listy
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Błąd AI lub parsowania: $e')),
        );
        setState(() => _aiError = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoadingAI = false);
    }
  }

  void _showWizardForm() {
    final descCtl = TextEditingController();
    DateTime? wizDate;

    showModalBottomSheet(
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
                ElevatedButton(
                  onPressed: (wizDate == null || descCtl.text.trim().isEmpty || _isLoadingAI)
                      ? null
                      : () {
                          Navigator.pop(ctx2);
                          _askWizardAI(descCtl.text.trim(), wizDate!);
                        },
                  child: _isLoadingAI
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Generuj i dodaj'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _addTaskManually() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uzupełnij wszystkie pola i wybierz datę')),
      );
      return;
    }
    final hours       = int.tryParse(_hoursCtl.text) ?? 0;
    final minutes     = int.tryParse(_minutesCtl.text) ?? 0;
    final czasTrwania = hours * 60 + minutes;

    final data = {
      'Nazwa':        _nameCtl.text,
      'Opis':         _descCtl.text,
      'waga':         _selectedWaga,
      'termin':       Timestamp.fromDate(_selectedDate!),
      'czas_trwania': czasTrwania,
      'zrobione':     false,
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc('demo_users')
          .collection('tasks')
          .add(data);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Błąd dodawania: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dodaj zadanie')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Alternatywa: Wizard AI
            ElevatedButton.icon(
              icon: _isLoadingAI
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: const Text('Wizard AI'),
              onPressed: _isLoadingAI ? null : _showWizardForm,
            ),
            if (_aiError != null) ...[
              const SizedBox(height: 8),
              Text(_aiError!, style: const TextStyle(color: Colors.red)),
            ],
            const Divider(height: 32),

            // Standardowy formularz dodawania
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
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
                    Row(
                      children: [
                        const Text('Waga: '),
                        const SizedBox(width: 12),
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
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Termin: '),
                        const SizedBox(width: 12),
                        Text(
                          _selectedDate != null
                              ? _selectedDate!.toLocal().toString().split(' ')[0]
                              : 'nie wybrano',
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(onPressed: _selectDate, child: const Text('Wybierz termin')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Flexible(
                          child: TextFormField(
                            controller: _hoursCtl,
                            decoration: const InputDecoration(labelText: 'Godziny'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: TextFormField(
                            controller: _minutesCtl,
                            decoration: const InputDecoration(labelText: 'Minuty'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _addTaskManually, child: const Text('Dodaj')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
