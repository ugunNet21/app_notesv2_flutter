import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class Note {
  int? id;
  String title;
  String description;

  Note({
    this.id,
    this.title = '',
    this.description = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'],
      description: map['description'],
    );
  }
}

class NoteController extends GetxController {
  final notes = <Note>[].obs;
  final newNote = Note().obs;
  final databaseHelper = DatabaseHelper.instance;

  @override
  void onInit() {
    super.onInit();
    _loadNotes();
  }

  void _loadNotes() async {
    notes.value = await databaseHelper.getNotes();
  }

  Future<void> addNote() async {
    final note = newNote.value;
    await databaseHelper.insert(note);
    notes.add(note);
    newNote.update((val) {
      val!.id = null;
      val.title = '';
      val.description = '';
    });
  }

  Future<void> updateNoteAt(int index) async {
    final note = notes[index];
    await databaseHelper.update(note);
    notes[index] = note;
  }

  Future<void> deleteNoteAt(int index) async {
    final note = notes[index];
    await databaseHelper.delete(note);
    notes.removeAt(index);
  }
}

class DatabaseHelper {
  static const _databaseName = 'notes_database.db';
  static const _databaseVersion = 1;

  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final pathToDatabase = path.join(databasePath, _databaseName);

    return await openDatabase(
      pathToDatabase,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        description TEXT
      )
    ''');
  }

  Future<List<Note>> getNotes() async {
    final database = await instance.database;
    final notesData = await database.query('notes');
    return notesData.map((noteMap) => Note.fromMap(noteMap)).toList();
  }

  Future<void> insert(Note note) async {
    final database = await instance.database;
    await database.insert('notes', note.toMap());
  }

  Future<void> update(Note note) async {
    final database = await instance.database;
    await database.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<void> delete(Note note) async {
    final database = await instance.database;
    await database.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }
}

class NoteApp extends StatelessWidget {
  final noteController = Get.put(NoteController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan'),
      ),
      body: Obx(
        () => ListView.builder(
          itemCount: noteController.notes.length,
          itemBuilder: (context, index) {
            final note = noteController.notes[index];
            return Dismissible(
              key: Key(note.id.toString()),
              onDismissed: (_) {
                noteController.deleteNoteAt(index);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Catatan dihapus')),
                );
              },
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16.0),
                child: const Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
              ),
              child: Card(
                child: ListTile(
                  title: Text(note.title),
                  subtitle: Text(note.description),
                  onTap: () {
                    Get.dialog(
                      AlertDialog(
                        title: const Text('Edit Catatan'),
                        content: SingleChildScrollView(
                          child: Column(
                            children: [
                              TextFormField(
                                initialValue: note.title,
                                onChanged: (value) {
                                  note.title = value;
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Judul',
                                ),
                              ),
                              TextFormField(
                                initialValue: note.description,
                                onChanged: (value) {
                                  note.description = value;
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Deskripsi',
                                ),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              noteController.updateNoteAt(index);
                              Get.back();
                            },
                            child: const Text('Simpan'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.dialog(
            AlertDialog(
              title: const Text('Tambah Catatan'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextFormField(
                      onChanged: (value) {
                        noteController.newNote.value.title = value;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Judul',
                      ),
                    ),
                    TextFormField(
                      onChanged: (value) {
                        noteController.newNote.value.description = value;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    noteController.addNote();
                    Get.back();
                  },
                  child: const Text('Simpan'),
                ),
              ],
            ),
          ).whenComplete(() {
            noteController._loadNotes();
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  Get.put(NoteController());
  runApp(GetMaterialApp(
    home: NoteApp(),
    debugShowCheckedModeBanner: false,
  ));
}
