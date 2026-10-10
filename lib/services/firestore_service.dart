import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';

class FirestoreService {
  final CollectionReference _tasksCollection =
  FirebaseFirestore.instance.collection('tasks');

  // Stream of tasks filtered by user ID
  Stream<List<Task>> getTasks(String userId) {
    return _tasksCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
    });
  }

  // Add Task
  Future<void> addTask(Task task) async {
    await _tasksCollection.add(task.toMap());
  }

  // Update Task
  Future<void> updateTask(String taskId, Map<String, dynamic> data) async {
    await _tasksCollection.doc(taskId).update(data);
  }

  // Toggle Completion
  Future<void> toggleTaskStatus(String taskId, bool currentStatus) async {
    await _tasksCollection.doc(taskId).update({
      'isCompleted': !currentStatus,
    });
  }

  // Delete Task
  Future<void> deleteTask(String taskId) async {
    await _tasksCollection.doc(taskId).delete();
  }
}