import 'package:equatable/equatable.dart';
import 'package:sentech_connect_app/core/utils/phone_number.dart';

/// The topics `POST /v1/support/messages` accepts (wire value = [name]).
enum SupportTopic { connecting, payment, pass, account, other }

/// How support may reply: the API takes an email or a South African mobile.
enum SupportContactKind { email, phone }

/// What is wrong with a draft before it is sent (checked on the device so a
/// typo does not cost a human check and a round trip; the server checks again).
enum SupportDraftIssue {
  messageTooShort,
  messageTooLong,
  contactInvalid,
  orderRefInvalid,
}

class SupportMessageDraft extends Equatable {
  const SupportMessageDraft({
    required this.topic,
    required this.contactKind,
    required this.contact,
    required this.message,
    this.orderRef = '',
  });

  static const minMessage = 10;
  static const maxMessage = 2000;
  static final _orderRef = RegExp(r'^[A-Za-z0-9-]{4,40}$');
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  final SupportTopic topic;
  final SupportContactKind contactKind;
  final String contact;
  final String message;
  final String orderRef;

  String get trimmedMessage => message.trim();

  /// The contact as the API wants it: an email as typed, a mobile as E.164.
  /// Null when it is not valid.
  String? get contactValue {
    final value = contact.trim();
    if (contactKind == SupportContactKind.phone) {
      return normaliseZaMobile(value);
    }
    return value.length <= 254 && _email.hasMatch(value) ? value : null;
  }

  String? get orderRefValue {
    final value = orderRef.trim();
    return value.isEmpty ? null : value;
  }

  SupportDraftIssue? get issue {
    final length = trimmedMessage.runes.length;
    if (length < minMessage) return SupportDraftIssue.messageTooShort;
    if (length > maxMessage) return SupportDraftIssue.messageTooLong;
    if (contactValue == null) return SupportDraftIssue.contactInvalid;
    final ref = orderRefValue;
    if (ref != null && !_orderRef.hasMatch(ref)) {
      return SupportDraftIssue.orderRefInvalid;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    topic,
    contactKind,
    contact.trim(),
    trimmedMessage,
    orderRefValue,
  ];
}

/// The answer to a sent message: the reference to quote when contacting
/// support again.
class SupportReceipt extends Equatable {
  const SupportReceipt(this.reference);

  final String reference;

  @override
  List<Object?> get props => [reference];
}
