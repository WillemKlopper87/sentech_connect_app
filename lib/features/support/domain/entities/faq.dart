import 'package:equatable/equatable.dart';

class Faq extends Equatable {
  const Faq({required this.id, required this.question, required this.answer});

  final String id;
  final String question;
  final String answer;

  @override
  List<Object?> get props => [id, question, answer];
}
