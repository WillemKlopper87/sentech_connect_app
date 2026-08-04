import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/support/domain/entities/faq.dart';
import 'package:sentech_connect_app/features/support/domain/repositories/support_repository.dart';

enum SupportStatus { loading, loaded, failure }

class SupportState extends Equatable {
  const SupportState({
    this.status = SupportStatus.loading,
    this.allFaqs = const [],
    this.query = '',
    this.expandedId,
  });

  final SupportStatus status;
  final List<Faq> allFaqs;
  final String query;
  final String? expandedId;

  List<Faq> get visibleFaqs {
    if (query.trim().isEmpty) return allFaqs;
    final q = query.toLowerCase();
    return allFaqs.where((f) => f.question.toLowerCase().contains(q)).toList();
  }

  SupportState copyWith({
    SupportStatus? status,
    List<Faq>? allFaqs,
    String? query,
    String? expandedId,
    bool clearExpanded = false,
  }) {
    return SupportState(
      status: status ?? this.status,
      allFaqs: allFaqs ?? this.allFaqs,
      query: query ?? this.query,
      expandedId: clearExpanded ? null : (expandedId ?? this.expandedId),
    );
  }

  @override
  List<Object?> get props => [status, allFaqs, query, expandedId];
}

class SupportCubit extends Cubit<SupportState> {
  SupportCubit(this._repository) : super(const SupportState()) {
    _load();
  }

  final SupportRepository _repository;

  Future<void> _load() async {
    final result = await _repository.getFaqs();
    result.match(
      (_) => emit(state.copyWith(status: SupportStatus.failure)),
      (faqs) => emit(state.copyWith(status: SupportStatus.loaded, allFaqs: faqs)),
    );
  }

  void search(String query) => emit(state.copyWith(query: query));

  void toggleExpanded(String id) {
    if (state.expandedId == id) {
      emit(state.copyWith(clearExpanded: true));
    } else {
      emit(state.copyWith(expandedId: id));
    }
  }
}
